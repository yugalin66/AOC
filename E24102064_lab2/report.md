# Lab 2 Homework Template

## Workload Analysis (10%)

### 1. Model Architecture

### 2. Profiling Results

### 3. Analysis and Comparison

## Analytical Model (15%)

### 1. GLB Usage

The memory requirements for GLB are determined by the number of data elements processed during a single processing pass, which includes the input feature map (8-bit elements per pixel), filter weights (8-bit elements per filter), biases (32-bit elements per filter), and partial sums (32-bit elements per pixel).

#### Ifmap GLB Usage

$$
\text{GLB usage of ifmap} = n \times qr \times (U(e-1) + R) \times W \times 1 ~ \text{byte}
$$

#### Filter GLB Usage

$$
\text{GLB usage of filter} = ??? \text{byte}
$$

#### Bias GLB Usage

$$
\text{GLB usage of bias} = ??? \text{byte}
$$

#### Psum & Ofmap GLB Usage

$$
\text{GLB usage of psum} = ??? \text{byte}
$$

Note: The ofmap and psum will share space in the GLB.

#### Validation

$$
\text{Valid}(\text{HardwareParam}, \text{MappingParam}) = \cases{
1 \text{ , } ??? \\
0 \text{ , otherwise}
}
$$

### 2. DRAM Access (Data Transfer between DRAM and GLB)

The data used by a single processing pass is only loaded from DRAM into GLB once and written back to DRAM once, so the total number of accesses to DRAM can be calculated by dividing the size of the entire layer by the amount of data processed per pass.

#### Ifmap DRAM Access

$$
\text{DRAM reads for ifmap} =
\overbrace{
    \left\lceil\frac{M}{m}\right\rceil
}^\text{refetch DRAM} \times
\overbrace{
    \left\lceil\frac{E}{e}\right\rceil \times
    \left\lceil\frac{N}{n}\right\rceil \times
    \left\lceil\frac{C}{qr}\right\rceil
}^\text{num of tiles} \times
\overbrace{
    n \times qr \times (U(e-1) + R) \times W \times 1 \text{byte}
}^\text{tile size}
$$

#### Filter DRAM Access

$$
\text{DRAM reads for filter} = ???
$$

#### Bias DRAM Access

$$
\text{DRAM reads for bias} =
???
$$

#### Ofmap DRAM Access

$$
\text{DRAM writes for ofmap} =
???
$$

### 3. GLB Access (Data Transfer between GLB and Spads)

#### Ifmap GLB Access

$$
\text{GLB reads for ifmap} =
\overbrace{
    \left\lceil\frac{M}{m}\right\rceil
}^\text{refetch DRAM} \times
\overbrace{
    \left\lceil\frac{E}{e}\right\rceil \times
    \left\lceil\frac{N}{n}\right\rceil \times
    \left\lceil\frac{C}{qr}\right\rceil
}^\text{num of tiles} \times
\overbrace{
    \left\lceil\frac{m}{pt}\right\rceil
}^\text{reuse in GLB} \times
\overbrace{
    n \times qr \times (U(e-1) + R) \times W \times 1 \text{byte}
}^\text{tile size}
$$

#### Filter GLB Access

$$
\text{GLB reads for filter} =
???
$$

#### Bias GLB Access

$$
\text{GLB reads for bias} =
???
$$

#### Psum GLB Access for Conv2D

$$
\text{GLB reads for psum} =
???
$$

$$
\text{GLB writes for psum} =
???
$$

#### Psum GLB Access for Requant, ReLU, and MaxPool

$$
\text{GLB reads for psum} =
???
$$

$$
\text{GLB writes for ofmap} =
\cases{
??? \text{ , if MaxPool} \\
??? \text{ , otherwise}
}
$$

### 4. MACs

The number of MACs (Multiply-Accumulate operations) required for a Convolutional layer depends only on its shape.

$$
\text{MACs} = N \times M \times E \times F \times C \times R \times S
$$

### 5. Latency

$$
\begin{align}
\text{latency}
&= \text{number of DRAM accesses} \times \text{DRAM access time per element} \\
&+ \text{number of GLB accesses} \times \text{SRAM access time per element} \\
&+ \text{PE array compute time} \\
&+ \text{ofmap size} \times \text{PPU compute time per element}
\end{align}
$$

Note that the computation time of the PE array overlaps with the GLB access time, but the exact proportion is difficult to estimate and is hence ignored for now. The compute latency of the Post-Processing Unit (PPU) can be conservatively assumed as

$$
\text{PPU compute time per element} =
\cases{
    5 \text{ cycles, if MaxPool} \\
    1 \text{ cycle, otherwise}
}
$$

### 6. Engery and Power Consumption

## Roofline Model (10%)

### 1. Operational Intensity of Conv2D

Derive the operational intensity of the 2D convolution kernel using the notation from the Eyeriss paper. Then, estimate its complexity with Big-O notation.

$$
I_\text{conv} = ??? = O(???)
$$

### 2. Roofline Model of Conv2D

Given a Conv2D kernel with the following size:

| N   | M   | C   | H/W | R/S | E/F | P (padding) | U (stride) |
| --- | --- | --- | --- | --- | --- | ----------- | ---------- |
| 1   | 64  | 3   | 32  | 3   | 32  | 1           | 1          |

On a hardware which provides peak performance **48 MACs/cycle** and **peak bandwidth 4 byte/cycle**, the roofline model are shown below:

> Plot the roofline model here

This Conv2D kernel is ____________-bound.

## Design Space Exploration (20%)

### 1. Optimal Mapping Parameters

|     | $m$ | $n$ | $e$ | $p$ | $q$ | $r$ | $t$ | Latency | Memory Access | Memory Usage |
| --- | --- | --- | --- | --- | --- | --- | --- | ------- | ------------- | ------------ |
| #1  |     |     |     |     |     |     |     |         |               |              |
| #2  |     |     |     |     |     |     |     |         |               |              |
| #3  |     |     |     |     |     |     |     |         |               |              |
| #4  |     |     |     |     |     |     |     |         |               |              |
| #5  |     |     |     |     |     |     |     |         |               |              |

### 2. Algorithm for Design Point Evaluation

Explain how you decide the optimal set of mapping parameters for the VGG-8 model running on Eyeriss DLA. Both Chinese and English are available.

### 3. Search Space Expansion for Hardware Configuration

## Feedback (Bonus 10%)
