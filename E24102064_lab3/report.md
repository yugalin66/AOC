# Lab 3 Report

## Lab Design Description (40%)

Scores will be assigned based on the level of detail and the logical soundness of your description.
Each section should ideally include a block diagram to explain the module.

### Explain how you implement PE

> Explain how you handle the computation of the zero point of dequantization.

I implement PE by a FSM of 7 states, which are idle, read filter, read ifmap, convolution, read ipsum, write opsum, done. Every state has a counter to calculate how many cycle should each state be execute.

* idle state (`IDLE`)
PE wait for PE_en to trigger PE and start to read i_config.

* read filter state (`READ_FILTER`)
PE pull `filter_ready` to high, read input `filter` (`q` channel in one cycle, total `p` cycles) iff both `filter_ready` and `filter_valid` are high, store `q` channel of  input filter in `filter_spad[filter_idx]` to `filter_spad[filter_idx + q]` with index `filter_idx`. `filter_idx` plus `q` after each read cycle. State changed into `READ_IFMAP` after `FILT_S` * `p` cycles.

* read ifmap state (`READ_IFMAP`)
PE pull `ifmap_ready` to high, read input `ifmap` (`q` channel in one cycle, first time read 3 cycles, and each time 1 cycle for the rest) iff both `ifmap_ready` and `ifmap_valid` are high. Do dequantization first, complement `ifmap[7]` (MSB), then store `q` channel of ifmap in `ifmap_spad[ifmap_idx]` to `ifmap_spad[ifmap_idx+q]` with index `ifmap_idx`. `ifmap_idx` plus `q` after the first read, `ifmap_spad` shift forward and read new input in the last spad for the rest cycles.

* convolution state (`CONV`)
In the `CONV` state, PE begins the convolution operation after the `filter` and `ifmap` have been read and stored in their respective `spad`. Do convolution in the sequence of spad then store psum in `ofmap_spad[mul_ofmap_idx]`, `mul_ofmap_idx` plus 1 after `FILT_S` * `q` times of MACs. Change state into `READ_IPSUM` when `mul_ofmap_idx` equals `p`

* read ipsum state (`READ_IPSUM`)
PE pull `ipsum_ready` to high, read `ipsum` when both `ipsum_ready` and `ipsum_valid` are high, add `ipsum` to `ofmap_spad[ipsum_idx]` in order. Change state into `WRITE_OPSUM` after p cycles.

* write opsum state (`WRITE_OPSUM`)
PE pull `opsum_valid` to high, write `ofmap_spad[ofmap_idx]` to output `opsum` when both `opsum_ready` and `opsum_valid` are high, `ofmap_idx` plus 1 after each write, change state into `READ_IFMAP` after `p` writes, change state into `DONE` after `F` writes.

* block diagram
![PE](./picture/PE.png)

### Explain how you implement PE array

> Including network (GIN/GON/LN) and multicast controller (MC)

#### GIN

GIN is responsible for distributing input data (ifmap, filter, ipsum) from the global buffer (GLB) to the PE array. Each type of data has a dedicated GIN module (`GIN_ifmap`, `GIN_filter`, `GIN_ipsum`). GIN uses a two-level bus structure (Y-bus and X-bus) and a multicast controller to deliver data to the correct PEs based on tag matching (`tag_X`, `tag_Y`). The scan chain (`set_XID`, `set_YID`, etc.) is used to configure the IDs of each PE for flexible mapping.

![GIN_image](./picture/GIN.png)

#### GON

GON collects the output partial sums (opsum) from all PEs and sends them back to the GLB. It also uses a two-level bus structure and multicast controller for flexible and efficient data collection. The GON module aggregates the outputs from the PE array and supports tag-based routing to ensure correct data delivery.

![GON_image](./picture/GON.png)

#### LN

The Local Network (LN) enables communication of partial sums (ipsum/opsum) between neighboring PEs, supporting vertical accumulation. The `LN_config` signal controls whether a PE receives its input partial sum from the GLB or from the PE above it, allowing for flexible dataflow (e.g., row-wise or column-wise accumulation).

![LN_image](./picture/LN.png)

#### MC

Each bus in GIN and GON is equipped with a multicast controller. The MC compares the configured ID of each PE with the incoming tag and enables data transfer only when they match. This mechanism allows efficient multicast and unicast, supporting various mapping strategies and maximizing data reuse.

![MC_image](./picture/MC.png)

#### PE array

* All PEs are instantiated in a generate loop, each receiving its own enable and configuration signals.
* GIN modules provide ifmap, filter, and ipsum data to the PEs, while GON collects opsum outputs.
* The always blocks connect the handshake signals and data between GIN/GON and the PEs.
* The LN logic determines the source of the ipsum for each PE (either from GLB or from the PE above), controlled by `LN_config`.

![PE_array_image](./picture//PE_array.png)

### Explain how you implement PPU

> Explain how you handle the computation of the zero point of requantization \
> Explain the order of 3 component(PostQuant, MaxPool, ReLU) and the reason why you design like that.

#### Zero Point of Requantization

In my design, the computation of the zero point of requantization is handled in the `post_quant` module. The input data (typically the accumulated partial sum from the PE array) is first right-shifted by the scaling factor to perform quantization. The output is then clamped to the 8-bit range (0~255) to fit the Qint8 format. The sign bit is also handled to ensure correct mapping to unsigned output. The zero point is implicitly handled by the bit manipulation and clamping logic, ensuring that the quantized output is centered correctly for the next layer.

Relevant code from `post_quant.sv`:

```
shift_data = data_in >>> scaling_factor;
if(~shift_data[`DATA_BITS-1] && (|shift_data[`DATA_BITS-2:7]))
    data_out = 8'd255;
else if(shift_data[`DATA_BITS-1] && !(&shift_data[`DATA_BITS-2:7]))
    data_out = 8'd0;
else
    data_out = {~shift_data[7],shift_data[6:0]};
```

#### Order of Components

In the `PPU` module, the order of the three components is as follows:

ReLU => PostQuant => MaxPool (if `maxpool_en`)

Reason for this order:

* ReLU is applied first (if enabled) to set negative values to zero before quantization. This ensures that only non-negative values are passed to the quantization stage, which is important for unsigned Qint8 output.
![ReLU_image](./picture/ReLU.png)
* PostQuant is performed next to convert the high-precision data to 8-bit quantized format, handling the scaling and zero point.
![post_quant_image](./picture/post_quant.png)
* MaxPool is applied last on the quantized data, selecting the maximum value within a pooling window. Pooling on quantized data is more efficient and matches the behavior of typical DNN frameworks.
![maxpool_image](./picture/maxpool.png)

### Result

| Component | Pass (Y/N) |
|:---------:|:----------:|
|    PE     |      Y     |
| PE array  |      Y     |
|    PPU    |      Y     |


## Question (50%)

### Question 1 (20%)

Explain how data reuse is achieved in the design presented in the Eyeriss paper.

- **Row Stationary (RS) Dataflow**: Optimizes data reuse by mapping computations in a spatial array, minimizing data movement across memory levels.
  
* **Types of Reuse**:

1. Convolutional Reuse: Filter weights and `ifmap` pixels are reused multiple times within the same planes.
2. Filter Reuse: Filters are reused across batches of `ifmaps`.
3. Ifmap Reuse: `ifmap` is reused across multiple filters to generate `ofmap` channels.
  
* **Efficient Memory Hierarchy**: Uses **spads** (local scratchpad memory) for low-cost, fast data storage, reducing reliance on high-cost DRAM.

### Question 2 (10%)

Compute a `16×16` Conv2D operation, given the following configuration

- Kernel size: `3×3`
- Stride: `1`
- Padding: `1`
- Global Buffer (GLB) size: `128 KB`
- Mapping parameters:
    - `p = 4`
    - `q = 4`
    - `r = 1`
    - `t = 2`
    - `e = 8`

Determine the value of the mapping parameter `m`

**Please include the calculation process.**

$$
\begin{aligned}
    \text{GLB ifmap usage} &= n \times qr \times (U(e-1+R)) \times W \times \text{1 byte} \\\\
    \text{GLB filter usage} &= pt \times qr \times RS \times \text{1 byte} \\\\
    \text{GLB bias usage} &= pt \times \text{4 bytes} \\\\
    \text{GLB psum usage} &= n \times m \times e \times F \times \text{4 byte} \\\\
\end{aligned}
$$
according to the bound of mappin parameters : 
$$ \text{GLB usage} < 128 \text{ KB} $$
and given configuration :
$$ R = S = 3, F = W = 16, n = 1, U = 1 $$
we can get :
$$
(4\times((8-1)+3)\times16) + (4\times2\times4\times3\times3) + (4\times2\times4) + (m\times8\times16\times4) \le 128*1024
$$
$$
m \le 254.125 \quad \text{so we can obtain : m} = 254
$$

### Question3 (10%)
In the testbench, explain how to compute the multicast controller’s ID (`X_ID`, `Y_ID`) and the data tags (`tag_X`, `tag_Y`) based on the mapping parameters and shape parameters.

### Understanding ID and Y_ID Assignment in PE Array

#### **Ifmap**:
- **X_ID**:
  $$
  \text{X_ID}_{\text{ifmap}} = \frac{PE_{\text{ARRAY_W}}}{\text{array_W_tile}} - 1
  $$
  - **Explanation**: The **X_ID** for **ifmap** is determined by dividing the **PE array width** by the **tile width (`array_W_tile`)**. This ensures that the **ifmap** data is correctly distributed across the **PE array**.

- **Y_ID**:
  $$
  \text{Y_ID}_{\text{ifmap}} = r - 1
  $$
  - **Explanation**: The **Y_ID** for **ifmap** is determined by how the rows are divided (`r`). The last row will have `Y_ID = r - 1`.

#### **Filter**:
- **X_ID**:
  $$
  \text{X_ID}_{\text{filter}} = \left( \frac{PE_{\text{ARRAY_H}}}{\text{array_H_tile}} \right) \times \text{array_W_tile} - 1
  $$
  - **Explanation**: The **X_ID** for **filter** is based on how the **PE array height (`PE_ARRAY_H`)** is divided by the filter row partition size (`array_H_tile`). This ensures that the filter data is mapped correctly to the **PE array**.

- **Y_ID**:
  $$
  \text{Y_ID}_{\text{filter}} = \text{array_H_tile} - 1
  $$
  - **Explanation**: The **Y_ID** for **filter** is assigned to the last row of each tile, ensuring correct distribution across the **PE array**.

#### **Ipsum**:
- **X_ID**:
  $$
  \text{X_ID}_{\text{ipsum}} = e \times t_W - 1 \quad \text{on every tile (t_H times)}
  $$
  - **Explanation**: The **X_ID** for **ipsum** is assigned to the last column of each tile (`t_H` times). The data is distributed across the tiles, ensuring that the last row of each tile has the correct **X_ID**.

- **Y_ID**:
  $$
  \text{Y_ID}_{\text{ipsum}} = 
  \begin{cases}
    t_H - 1 & \text{on every tile (merge_num times)} \\
    PE_{\text{ARRAY_W}} - 1 & \text{on other rows}
  \end{cases}
  $$
  - **Explanation**: The **Y_ID** for **ipsum** is assigned to the last row of each tile. For other rows, the **Y_ID** is distributed across the **PE array** with a value of `PE_ARRAY_W - 1`.

#### **Opsum**:
- **X_ID**:
  $$
  \text{X_ID}_{\text{opsum}} = e \times t_W - 1 \quad \text{on every tile (t_H times)}
  $$
  - **Explanation**: The **X_ID** for **opsum** is assigned in the same way as **ipsum**, but specifically for the last row of each tile. This ensures that the accumulated **opsum** data is mapped correctly across the **PE array**.

- **Y_ID**:
  $$
  \text{Y_ID}_{\text{opsum}} = 
  \begin{cases}
    t_H - 1 & \text{on every tile (merge_num times)} \\
    PE_{\text{ARRAY_W}} - 1 & \text{on other rows}
  \end{cases}
  $$
  - **Explanation**: The **Y_ID** for **opsum** follows the same logic as **ipsum**, but it is assigned to the last row of each **PE set**. For rows other than the last, the **Y_ID** is distributed across the **PE array**.

---

### **Data Tags**

#### **Ifmap**:
- **tag_X**:
  $$
  \text{tag_X}_{\text{ifmap}} = \text{count_ifmap_row} + (e + R - 2)
  $$
  - **Explanation**: The **tag_X** for **ifmap** is assigned based on the row index (`count_ifmap_row`) and the number of output channels (`e`) and row partitions (`R`).

- **tag_Y**:
  $$
  \text{tag_Y}_{\text{ifmap}} = \text{count_r} + (r - 1)
  $$
  - **Explanation**: The **tag_Y** for **ifmap** is assigned based on the current row partition (`count_r`).

#### **Filter**:
- **tag_X**:
  $$
  \text{tag_X}_{\text{filter}} = \text{count_filter_row} + \text{FILT_ROW} \times (\text{count_t_W}) \times (R - 1 + R \times (t_W - 1))
  $$
  - **Explanation**: The **tag_X** for **filter** is determined by the row index (`count_filter_row`), filter row size (`FILT_ROW`), and tiling in the **X-direction** (`count_t_W`).

- **tag_Y**:
  $$
  \text{tag_Y}_{\text{filter}} = (\text{count_r} + \text{count_t_H}) \times (r - 1 + t_H - 1)
  $$
  - **Explanation**: The **tag_Y** for **filter** is determined by the row index (`count_r`) and tile index (`count_t_H`), adjusted for the row partitions (`r - 1 + t_H - 1`).

#### **Ipsum**:
- **tag_X**:
  $$
  \text{tag_X}_{\text{ipsum}} = \text{count_ipsum_row} + e \times \text{count_t_W} \times (e - 1 + e \times (t_W - 1))
  $$
  - **Explanation**: The **tag_X** for **ipsum** is based on the current row index (`count_ipsum_row`), the number of output channels (`e`), and the tiling (`count_t_W`).

- **tag_Y**:
  $$
  \text{tag_Y}_{\text{ipsum}} = \text{count_t_H}
  $$
  - **Explanation**: The **tag_Y** for **ipsum** is assigned based on the tile index (`count_t_H`).

#### **Opsum**:
- **tag_X**:
  $$
  \text{tag_X}_{\text{opsum}} = \text{count_ofmap_row} + e \times \text{count_t_W} \times (e - 1 + e \times (t_W - 1))
  $$
  - **Explanation**: The **tag_X** for **opsum** follows the same logic as **ipsum**, but it is mapped to the last row of each tile for accumulation.

- **tag_Y**:
  $$
  \text{tag_Y}_{\text{opsum}} = \text{count_t_H}
  $$
  - **Explanation**: The **tag_Y** for **opsum** is assigned to the last row of each **PE set**, similar to **ipsum**.

### Question 4 (10%)

For the test case where e = 4,
why are the configurations `(r, t)` = `(1, 4)` and `(2, 2)` present, but `(4, 1)` is not?
What do you think is the reason behind this?

Since r means the number of PE sets that calculate different channels, so when r = 4, we need to devide PE array's row by 4. But our number of PE array's row = 6, we can't devide 6 by 4, that's why (4, 1) is not a reasonable configuration.

## Lab Feedback and Suggestions (10%)
* maybe using VCS will be better instead of using verilator
* It would be better if I/O port connection between modules and their behavior are provided in a diagram