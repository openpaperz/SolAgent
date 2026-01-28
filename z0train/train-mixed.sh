#!/bin/bash

CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7,8 /home/chenwei/miniforge3/envs/torch/bin/python train_sft.py \
  --data_path output/processed_mixed.json \
  --output_dir output/pxcoder-mixed \
  --num_train_epochs 3 \
  --per_device_train_batch_size 1 #\
  # --gradient_accumulation_steps 2 \
  # --gradient_checkpointing True \
  # --learning_rate 1e-5 \
  # --max_seq_length 2048