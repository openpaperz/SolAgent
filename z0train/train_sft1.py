#!/usr/bin/env python3
"""
SFT Training Script
Fine-tune on Qwen3-8B using TRL's SFTTrainer
"""

import os
import json
import copy
import torch
import logging
from pathlib import Path
from typing import List, Dict, Any
from dataclasses import dataclass, field

from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    BitsAndBytesConfig,
    TrainingArguments,
    HfArgumentParser,
)
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training
from trl import SFTTrainer
from datasets import Dataset

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

@dataclass
class ModelArguments:
    """Model-related arguments"""
    model_name_or_path: str = field(
        default="Qwen/Qwen3-8B",
        metadata={"help": "Pre-trained model name or path"}
    )
    use_4bit: bool = field(
        default=False,
        metadata={"help": "Whether to use 4bit quantization"}
    )
    use_lora: bool = field(
        default=False,
        metadata={"help": "Whether to use LoRA"}
    )


@dataclass
class DataArguments:
    """Data-related arguments"""
    data_path: str = field(
        default="output/processed_tracker.json",
        metadata={"help": "Training data path"}
    )
    max_seq_length: int = field(
        default=4096,
        metadata={"help": "Maximum sequence length (used to set tokenizer.model_max_length)"}
    )


@dataclass
class TrainingArgs(TrainingArguments):
    """Training arguments"""
    output_dir: str = field(
        default="output/pxcoder-test"
    )
    num_train_epochs: int = field(default=3)
    per_device_train_batch_size: int = field(default=1)
    per_device_eval_batch_size: int = field(default=1)
    gradient_accumulation_steps: int = field(default=2)
    learning_rate: float = field(default=2e-4)
    warmup_ratio: float = field(default=0.03)
    logging_steps: int = field(default=10)
    eval_strategy: str = field(default="steps")
    save_steps: int = field(default=36)
    save_strategy: str = field(default="steps")
    eval_steps: int = field(default=36)
    # evaluation_strategy: str = field(default="steps")
    save_total_limit: int = field(default=3)
    fp16: bool = field(default=False)
    bf16: bool = field(default=True)
    # optim: str = field(default="paged_adamw_8bit")
    gradient_checkpointing: bool = field(default=False)
    report_to: str = field(default="none")
    dataset_text_field: str = field(default="messages")
    # max_length: int = field(default=4096)
    packing: bool = field(default=False)
    load_best_model_at_end: bool = field(default=True)
    metric_for_best_model: str = field(default="loss")


def detect_device():
    """Auto-detect available device: CUDA > MPS > CPU"""
    if torch.cuda.is_available():
        device = "cuda"
        logger.info(f"✅ Using CUDA device: {torch.cuda.get_device_name(0)}")
        logger.info(f"   GPU Memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.2f} GB")
    elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
        device = "mps"
        logger.info("✅ Using Apple Silicon MPS device")
    else:
        device = "cpu"
        logger.info("⚠️  Using CPU (training will be slow)")
    
    return device


def load_data(data_path: str) -> List[Dict[str, Any]]:
    """Load processed data (prefer resolving relative paths relative to script directory)"""
    p = Path(data_path)
    candidates = []
    if p.is_absolute():
        candidates.append(p)
    else:
        script_dir = Path(__file__).resolve().parent
        # 1) Relative to train_sft.py directory
        candidates.append(script_dir / p)
        # 2) As current working directory relative path (fallback)
        candidates.append(Path.cwd() / p)

    logger.info(f"Loading data from {data_path}")
    for cand in candidates:
        if cand.exists():
            with open(cand, 'r', encoding='utf-8') as f:
                data = json.load(f)
            logger.info(f"Loaded {len(data)} samples from {cand}")
            return data

    raise FileNotFoundError(
        f"Data file not found. Tried: {', '.join(str(c) for c in candidates)}"
    )


def prepare_dataset(data: List[Dict[str, Any]], train_ratio: float = 0.8):
    """Prepare Dataset object and split train/validation sets
    
    Split by source_file groups to ensure samples from the same source_file don't appear in both train and validation sets
    """
    # Preprocessing: normalize tool_calls structure, ensure arguments are strings and function field exists
    def normalize_messages(messages: List[Dict[str, Any]]):
        for msg in messages:
            tool_calls = msg.get("tool_calls")
            if not tool_calls:
                continue

            for tc in tool_calls:
                fn = tc.get("function") if isinstance(tc.get("function"), dict) else {}

                # Unify arguments: dict -> JSON str, None -> ""
                arguments = fn.get("arguments", tc.get("arguments"))
                if isinstance(arguments, dict):
                    arguments = json.dumps(arguments, ensure_ascii=False)
                elif arguments is None:
                    arguments = ""

                # Ensure function structure is complete
                fn.setdefault("name", tc.get("name", ""))
                fn["arguments"] = arguments
                tc["function"] = fn

                # Top-level fields also keep as strings to avoid Arrow type inference issues
                tc["arguments"] = arguments
                tc["name"] = tc.get("name", fn.get("name", ""))

        return messages

    # Deep copy and normalize data to avoid modifying original data
    normalized_data = []
    for sample in data:
        sample_copy = copy.deepcopy(sample)
        sample_copy["messages"] = normalize_messages(sample_copy["messages"])
        # tools may be empty list, keep consistency
        sample_copy["tools"] = sample_copy.get("tools", []) or []
        normalized_data.append(sample_copy)

    data = normalized_data
    # Group by source_file
    import random
    from collections import defaultdict
    
    file_groups = defaultdict(list)
    for idx, sample in enumerate(data):
        source_file = sample.get("source_file", "unknown")
        file_groups[source_file].append(idx)
    
    # Get all source_file list and shuffle randomly
    source_files = list(file_groups.keys())
    random.seed(42)
    random.shuffle(source_files)
    
    # Split source_file by ratio
    num_train_files = int(len(source_files) * train_ratio)
    train_files = set(source_files[:num_train_files])
    eval_files = set(source_files[num_train_files:])
    
    logger.info(f"Total unique source files: {len(source_files)}")
    logger.info(f"Train files: {len(train_files)}, Eval files: {len(eval_files)}")
    
    # Assign samples based on source_file
    train_indices = []
    eval_indices = []
    
    for source_file, indices in file_groups.items():
        if source_file in train_files:
            train_indices.extend(indices)
        else:
            eval_indices.extend(indices)
    
    # Create training and validation sets
    train_data = [data[i] for i in train_indices]
    eval_data = [data[i] for i in eval_indices]
    
    train_dataset_dict = {
        "messages": [sample["messages"] for sample in train_data],
        "tools": [sample.get("tools", []) for sample in train_data],
        "source_file": [sample.get("source_file", "") for sample in train_data]
    }
    eval_dataset_dict = {
        "messages": [sample["messages"] for sample in eval_data],
        "tools": [sample.get("tools", []) for sample in eval_data],
        "source_file": [sample.get("source_file", "") for sample in eval_data]
    }
    
    train_dataset = Dataset.from_dict(train_dataset_dict)
    eval_dataset = Dataset.from_dict(eval_dataset_dict)
    
    logger.info(f"✅ Train samples: {len(train_dataset)}")
    logger.info(f"✅ Eval samples: {len(eval_dataset)}")
    
    return train_dataset, eval_dataset


def create_bnb_config(use_4bit: bool) -> BitsAndBytesConfig:
    """Create BitsAndBytes quantization configuration"""
    if not use_4bit:
        return None
    
    bnb_config = BitsAndBytesConfig(
        load_in_4bit=True,
        bnb_4bit_quant_type="nf4",
        bnb_4bit_compute_dtype=torch.float16,
        bnb_4bit_use_double_quant=True,
    )
    
    logger.info("✅ 4bit quantization enabled")
    return bnb_config


def create_lora_config() -> LoraConfig:
    """Create LoRA configuration"""
    lora_config = LoraConfig(
        r=16,
        lora_alpha=32,
        target_modules=[
            "q_proj",
            "k_proj", 
            "v_proj",
            "o_proj",
            "gate_proj",
            "up_proj",
            "down_proj"
        ],
        lora_dropout=0.05,
        bias="none",
        task_type="CAUSAL_LM",
    )
    
    logger.info("✅ LoRA config created")
    logger.info(f"   Rank: {lora_config.r}")
    logger.info(f"   Alpha: {lora_config.lora_alpha}")
    logger.info(f"   Target modules: {len(lora_config.target_modules)}")
    
    return lora_config


def load_model_and_tokenizer(model_args: ModelArguments, device: str, training_args: TrainingArgs):
    """Load model and tokenizer"""
    logger.info(f"Loading model: {model_args.model_name_or_path}")
    
    # Create quantization configuration
    bnb_config = create_bnb_config(model_args.use_4bit)
    
    # Load tokenizer
    tokenizer = AutoTokenizer.from_pretrained(
        model_args.model_name_or_path,
        trust_remote_code=True,
        padding_side="right",
    )
    
    # Ensure pad token exists
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
    # Keep recent content more suitable for dialogue, avoid truncating tail answer
    tokenizer.truncation_side = "left"

    logger.info("✅ Tokenizer loaded")
    
    # Load model
    # use_bf16 = bool(training_args.bf16) and torch.cuda.is_available() and torch.cuda.is_bf16_supported()
    # if use_bf16:
    #     torch_dtype = torch.bfloat16
    # elif bool(training_args.fp16):
    #     torch_dtype = torch.float16
    # else:
    #     torch_dtype = torch.float32

    model = AutoModelForCausalLM.from_pretrained(
        model_args.model_name_or_path,
        quantization_config=bnb_config,
        device_map="auto" if device == "cuda" else None,
        trust_remote_code=True,
        torch_dtype=torch.float16 if device == "cuda" else torch.float32,
        use_cache=False,
    )
    
    logger.info("✅ Model loaded")

    # Align special tokens: if tokenizer doesn't have BOS, use PAD as BOS,
    # and sync to model.config / generation_config to avoid runtime warnings and inconsistencies.
    try:
        if tokenizer.bos_token_id is None:
            tokenizer.bos_token = tokenizer.pad_token
            # bos_token_id will sync to pad_token_id with bos_token
        if hasattr(model, "config"):
            model.config.pad_token_id = tokenizer.pad_token_id
            # Only sync when bos_token_id exists
            if tokenizer.bos_token_id is not None:
                model.config.bos_token_id = tokenizer.bos_token_id
        if hasattr(model, "generation_config") and model.generation_config is not None:
            model.generation_config.pad_token_id = tokenizer.pad_token_id
            if tokenizer.bos_token_id is not None:
                model.generation_config.bos_token_id = tokenizer.bos_token_id
        logger.info(
            f"✅ Special tokens aligned: pad_token_id={tokenizer.pad_token_id}, bos_token_id={tokenizer.bos_token_id}"
        )
    except Exception as e:
        logger.warning(f"Special token alignment skipped: {e}")
    
    # If using quantization, prepare model
    if model_args.use_4bit:
        model = prepare_model_for_kbit_training(model)
        logger.info("✅ Model prepared for k-bit training")
    
    # Apply LoRA
    if model_args.use_lora:
        lora_config = create_lora_config()
        model = get_peft_model(model, lora_config)
        model.print_trainable_parameters()

    # Enable gradient checkpointing, ensure consistent with use_cache disabled
    if bool(training_args.gradient_checkpointing):
        try:
            model.gradient_checkpointing_enable()
        except Exception:
            # Some models have different APIs, ignore exception
            pass
        if hasattr(model, "config"):
            model.config.use_cache = False
        logger.info("✅ Gradient checkpointing enabled (use_cache=False)")
    
    return model, tokenizer





def train(
    model_args: ModelArguments,
    data_args: DataArguments,
    training_args: TrainingArgs,
):
    """Main training function"""
    
    logger.info("="*80)
    logger.info("🚀 Starting SFT Training for Agentic Coder")
    logger.info("="*80)
    
    # Detect device
    device = detect_device()
    
    # Adjust training parameters based on device
    # if device == "cuda":
    #     training_args.fp16 = True
    # elif device == "mps":
    #     # MPS doesn't support fp16, use fp32
    #     training_args.fp16 = False
    #     training_args.bf16 = False
    
    # Load data
    data = load_data(data_args.data_path)
    train_dataset, eval_dataset = prepare_dataset(data)
    
    # Validate data format (check tool_calls)
    sample_with_tools = next((s for s in data if any(m.get("tool_calls") for m in s["messages"])), None)
    if sample_with_tools:
        tool_msg_count = sum(1 for s in data for m in s["messages"] if m.get("tool_calls"))
        logger.info(f"✅ Found {tool_msg_count} messages with tool_calls")
        logger.info(f"   Sample message with tool_calls: {sample_with_tools['messages'][0].get('role', 'N/A')}")
    
    # Load model and tokenizer
    model, tokenizer = load_model_and_tokenizer(model_args, device, training_args)
    # Unify maximum sequence length (compatible with current TRL version, don't pass to SFTTrainer)
    try:
        tokenizer.model_max_length = int(data_args.max_seq_length)
        logger.info(f"✅ Set tokenizer.model_max_length = {tokenizer.model_max_length}")
    except Exception as e:
        logger.warning(f"Failed to set tokenizer.model_max_length: {e}")

    # To avoid Accelerate's GradScaler unscale issue: keep model weights as FP16, but disable AMP (fp16=False)
    # This won't call GradScaler.unscale_, thus avoiding 'Attempting to unscale FP16 gradients' error
    if bool(training_args.fp16):
        training_args.fp16 = False
        logger.info("⚙️  Using FP16 weights (torch_dtype=float16) but disabling AMP autocast (fp16=False) to avoid GradScaler unscale error")
    # dataset_text = dataset.map(
    #     lambda ex: {"text": format_messages_scheme_a(ex["messages"])},
    #     remove_columns=[],
    # )
    
    # Create output directory
    os.makedirs(training_args.output_dir, exist_ok=True)
    # Response and instruction templates for scheme A (note: both contain leading and trailing newlines)
    # rtxt = "\n### Assistant:\n"
    # itxt = "\n### User:\n"

    # response_template_ids    = tokenizer.encode(rtxt, add_special_tokens=False)
    # instruction_template_ids = tokenizer.encode(itxt, add_special_tokens=False)

    # collator = DataCollatorForCompletionOnlyLM(
    #     response_template    = response_template_ids,
    #     instruction_template = instruction_template_ids,
    #     tokenizer            = tokenizer
    # )
    # training_args.dataset_text_field = "text"
    # training_args.packing = False  # Must be False
    def formatting_prompts_func(example: Dict[str, Any]) -> str:
        return tokenizer.apply_chat_template(
            example["messages"],
            # tools=example.get("tools", None),
            tokenize=False,   # Let Trainer tokenize again
            add_generation_prompt=False
        )
    
    # assert chat template works
    # sample = train_dataset[0]  # or data[0]
    # prompt = formatting_prompts_func(sample)
    # # print(prompt)
    # # 1️⃣ Confirm tools block exists
    # assert "<tools>" in prompt, "❌ tools tag not found in prompt"
    # # 2️⃣ Confirm specific tool name appears
    # assert "myfile_system---list_files" in prompt, "❌ tool name not injected"
    # # 3️⃣ Confirm tool_call instruction exists
    # assert "<tool_call>" in prompt, "❌ tool_call instruction missing"

    # Create trainer
    logger.info("Creating SFTTrainer...")
    trainer = SFTTrainer(
        model=model,
        args=training_args,
        train_dataset=train_dataset,
        eval_dataset=eval_dataset,
        processing_class=tokenizer,
        # data_collator=collator,
        # max_seq_length=data_args.max_seq_length,
        formatting_func=formatting_prompts_func,
    )
    
    logger.info("✅ Trainer created")
    logger.info(f"   Output dir: {training_args.output_dir}")
    logger.info(f"   Epochs: {training_args.num_train_epochs}")
    logger.info(f"   Batch size: {training_args.per_device_train_batch_size}")
    logger.info(f"   Gradient accumulation: {training_args.gradient_accumulation_steps}")
    logger.info(f"   Learning rate: {training_args.learning_rate}")

    # Disable gradient clipping under FP16 to avoid Accelerate triggering 'Attempting to unscale FP16 gradients' during unscale
    if bool(training_args.fp16):
        try:
            training_args.max_grad_norm = 0.0
            logger.info("⚙️  FP16 detected: disabling gradient clipping (max_grad_norm=0.0) to avoid GradScaler unscale error")
        except Exception:
            pass

    # 🧪 Quick self-check: ensure labels are not all ignored (-100)
    try:
        dl = trainer.get_train_dataloader()
        first_batch = next(iter(dl))
        first_batch = next(iter(dl))
        labels = first_batch.get("labels")
        
        print("labels unique:", torch.unique(labels))
        print("num ignore:", (labels == -100).sum())
        print("num total:", labels.numel())

        mask = labels != -100
        print("Valid label count:", mask.sum())

        ids = first_batch["input_ids"][0]
        labs = first_batch["labels"][0]

        print("input:")
        print(tokenizer.decode(ids))

        print("\nlabels:")
        print(tokenizer.decode(ids[labs != -100]))

        if isinstance(labels, torch.Tensor):
            valid = (labels != -100)
            total = labels.numel()
            non_ignored = int(valid.sum().item())
            ratio = (non_ignored / total) if total > 0 else 0.0
            logger.info(
                f"🧪 Label mask check: non-ignored tokens {non_ignored}/{total} ({ratio*100:.2f}%)"
            )
            if non_ignored == 0:
                logger.warning("⚠️ All labels are -100 (ignored). Loss would be 0. Check formatting/collator.")
        else:
            logger.warning(f"Labels are not a tensor (type={type(labels).__name__}).")
    except Exception as e:
        logger.warning(f"Label mask check failed: {e}")
    
    # Start training
    logger.info("\n" + "="*80)
    logger.info("🏃 Starting training...")
    logger.info("="*80 + "\n")
    # ===== Sanity Check (can be commented out) =====
    # sample_text = dataset_text[0]["text"]
    # enc = tokenizer(sample_text, return_tensors="pt")
    # batch = collator([enc])
    # labels = batch["labels"][0].tolist()

    # start = next((i for i, x in enumerate(labels) if x != -100), None)
    # end   = len(labels) - 1 - next((i for i, x in enumerate(reversed(labels)) if x != -100), None)
    # snippet = tokenizer.decode(batch["input_ids"][0][start:end], skip_special_tokens=False)

    # logger.info("---- SFT Loss Span Preview ----")
    # logger.info(snippet[:500].replace("\n", "\\n"))  # Only show first 500 characters
    # # ====================================

    trainer.train()
    
    # Save model
    logger.info("\n" + "="*80)
    logger.info("💾 Saving model...")
    logger.info("="*80)
    
    trainer.save_model(training_args.output_dir)
    tokenizer.save_pretrained(training_args.output_dir)
    
    logger.info(f"✅ Model saved to {training_args.output_dir}")
    
    logger.info("\n" + "="*80)
    logger.info("🎉 Training completed successfully!")
    logger.info("="*80)


def main():
    """Main function"""
    parser = HfArgumentParser((ModelArguments, DataArguments, TrainingArgs))
    model_args, data_args, training_args = parser.parse_args_into_dataclasses()

    from modelscope import snapshot_download
    model_path = snapshot_download(model_args.model_name_or_path)
    model_args.model_name_or_path = model_path
    
    train(model_args, data_args, training_args)


if __name__ == "__main__":
    main()
