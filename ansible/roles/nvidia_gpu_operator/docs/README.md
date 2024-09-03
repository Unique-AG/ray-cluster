# Developer notes on the NVIDIA GPU Operator

## Helm Default Values

Refer to the `default_values.yaml` file for the default values used by the NVIDIA GPU Operator.

## Mig Strategy (LLM-generated README)

#### 1. MIG (Multi-Instance GPU):
   MIG is a feature that allows a single GPU to be partitioned into multiple smaller, isolated GPU instances. Each instance has its own memory, cache, and compute cores.

#### 2. MIG strategy:
   - `single`: This is the default strategy. It means that the entire GPU is treated as a single unit, without any partitioning.
   - `mixed`: This strategy allows for a mix of MIG-enabled and non-MIG-enabled GPUs in the same cluster.

#### 3. Why change from `single` to `mixed`:
   - Flexibility: The `mixed` strategy provides more flexibility in GPU utilization. It allows some GPUs to be partitioned using MIG while others remain as full, non-partitioned GPUs.
   - Resource optimization: In a cluster with diverse workloads, some tasks might benefit from smaller, isolated GPU instances (MIG), while others might need full GPU power. The `mixed` strategy accommodates both scenarios.
   - Gradual adoption: It allows for a phased approach in adopting MIG, where you can experiment with MIG on some GPUs while keeping others in their traditional configuration.

By changing to `mixed`, you're essentially telling the NVIDIA GPU Operator to support both MIG-enabled and non-MIG-enabled GPUs in your Kubernetes cluster, providing more flexibility in how GPU resources are allocated and used by different workloads.