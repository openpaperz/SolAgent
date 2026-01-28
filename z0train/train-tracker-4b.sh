#!/bin/bash
source /usr/local/Ascend/ascend-toolkit/set_env.sh
source /usr/local/Ascend/nnal/atb/set_env.sh

set -euo pipefail

# =======================
# parameter validation and default values
# =======================
if [ "$#" -lt 1 ]; then
  echo "Usage: $0 [device_type]"
  echo "  device_type: cuda (default) or npu"
  exit 1
fi

# export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:256

size=64
DATA_PATH=output/processed_tracker.json
OUTPUT_DIR=output/solagent-${size}k-tracker-4b-instruct-lora
MODEL_NAME_OR_PATH=Qwen/Qwen3-4B-Instruct-2507
MAX_LENGTH=$((size*1024))
#262144
DEVICE_TYPE=${1:-cuda}  # default to CUDA, use NPU if the third argument is npu

# =======================
# check data and output directory
# =======================
if [ ! -f "$DATA_PATH" ]; then
  echo "Error: data file '$DATA_PATH' does not exist."
  exit 1
fi

if [ ! -d "$OUTPUT_DIR" ]; then
  echo "Output directory '$OUTPUT_DIR' does not exist. Creating..."
  mkdir -p "$OUTPUT_DIR"
fi

# =======================
# device
# =======================
if [ "$DEVICE_TYPE" == "cuda" ]; then
  export CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7
elif [ "$DEVICE_TYPE" == "npu" ]; then
  export NPROC_PER_NODE=8
  export ASCEND_RT_VISIBLE_DEVICES=0,1,2,3,4,5,6,7
else
  echo "Error: device_type must be 'cuda' or 'npu'"
  exit 1
fi

accelerate launch train_sft_swift.py \
  --data_path $DATA_PATH \
  --output_dir $OUTPUT_DIR \
  --model_name_or_path $MODEL_NAME_OR_PATH \
  --max_length $MAX_LENGTH \
  --num_train_epochs 3 \
  --attn_impl flash_attn \
  --use_lora \
  --lora_rank 16 \
  --lora_alpha 32 \
  --per_device_train_batch_size 1 > $OUTPUT_DIR.log 2>&1
