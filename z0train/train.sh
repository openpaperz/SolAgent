#!/bin/bash
set -euo pipefail

# =======================
# parameter validation and default values
# =======================
if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <data_path> <output_dir> [device_type]"
  echo "  device_type: cuda (default) or npu"
  exit 1
fi

DATA_PATH=$1
OUTPUT_DIR=$2
DEVICE_TYPE=${3:-cuda}  # default to CUDA, use NPU if the third argument is npu

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
  export ASCEND_RT_VISIBLE_DEVICES=0,1,2,3,4,5,6,7
else
  echo "Error: device_type must be 'cuda' or 'npu'"
  exit 1
fi

accelerate launch train_sft.py \
  --data_path $1 \
  --output_dir $2 \
  --num_train_epochs 3 \
  --per_device_train_batch_size 1 #\
  # --gradient_accumulation_steps 2 \
  # --gradient_checkpointing True \
  # --learning_rate 1e-5 \
  # --max_seq_length 2048