import torch
import torch.nn as nn
import torch.ao.quantization as tq


class VGG(nn.Module):
    """ Implement your model here """
    def __init__(self, in_channels=3, in_size=32, num_classes=10) -> None:
        super().__init__()
        
        # Conv1: 3 -> 64 + MaxPool
        self.conv1 = nn.Sequential(
            nn.Conv2d(in_channels, 64, kernel_size=3, stride=1, padding=1),
            nn.BatchNorm2d(64),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(kernel_size=2, stride=2)
        )
        
        # Conv2: 64 -> 192 + MaxPool
        self.conv2 = nn.Sequential(
            nn.Conv2d(64, 192, kernel_size=3, stride=1, padding=1),
            nn.BatchNorm2d(192),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(kernel_size=2, stride=2)
        )
        # Conv3: 192 -> 384
        self.conv3 = nn.Sequential(
            nn.Conv2d(192, 384, kernel_size=3, stride=1, padding=1),
            nn.BatchNorm2d(384),
            nn.ReLU(inplace=True)
        )
        # Conv4: 384 -> 256
        self.conv4 = nn.Sequential(
            nn.Conv2d(384, 256, kernel_size=3, stride=1, padding=1),
            nn.BatchNorm2d(256),
            nn.ReLU(inplace=True)
        )
        # Conv5: 256 -> 256 + MaxPool
        self.conv5 = nn.Sequential(
            nn.Conv2d(256, 256, kernel_size=3, stride=1, padding=1),
            nn.BatchNorm2d(256),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(kernel_size=2, stride=2)
        )
        
        # Calculate the feature map spatial size after three poolings.
        fmap_size = in_size // 8  # Each 2x2 pooling halves the spatial dimensions
        
        # Fully connected layers:
        # FC6: Linear (256 * fmap_size^2 → 256)
        self.fc6 = nn.Sequential(
            nn.Linear(256 * fmap_size * fmap_size, 256),
            nn.ReLU(inplace=True)
        )
        # FC7: Linear (256 → 128)
        self.fc7 = nn.Sequential(
            nn.Linear(256, 128),
            nn.ReLU(inplace=True)
        )
        # FC8: Linear (128 → num_classes)
        self.fc8 = nn.Linear(128, num_classes)
        
    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = self.conv1(x)
        x = self.conv2(x)
        x = self.conv3(x)
        x = self.conv4(x)
        x = self.conv5(x)
        x = torch.flatten(x, start_dim=1)
        x = self.fc6(x)
        x = self.fc7(x)
        x = self.fc8(x)
        return x

    def fuse_modules(self):
        self.eval()
        modules_to_fuse = [
            ['conv1.0', 'conv1.1', 'conv1.2'],  # Conv2d + BN + ReLU
            ['conv2.0', 'conv2.1', 'conv2.2'],
            ['conv3.0', 'conv3.1', 'conv3.2'],
            ['conv4.0', 'conv4.1', 'conv4.2'],
            ['conv5.0', 'conv5.1', 'conv5.2']
        ]
        tq.fuse_modules(self, modules_to_fuse, inplace=True)

if __name__ == "__main__":
    model = VGG()
    inputs = torch.randn(1, 3, 32, 32)
    print(model)
    
    from torchsummary import summary

    summary(model, (3, 32, 32), device="cpu")