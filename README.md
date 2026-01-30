# SolAgent - A Specialized Multi-Agent Framework for Solidity Code Generation

SolAgent is an intelligent agent system for generating Solidity smart contract code. This project includes baseline implementations, the main SolAgent system, and ablation study experiments.

## Project Structure

```
.
├── baseline_*.py              # Baseline agent implementations
├── main.py                    # Main SolAgent implementation
├── main_nopatch.py           # SolAgent main entrypoint
├── main_ablation_*.py        # Ablation study experiments
├── coding.yaml               # Code generation agent configuration
├── refine.yaml               # Refinement agent configuration
├── data/                     # Dataset files
├── output/                   # Output directory for results
├── db/                       # Database tracking modules
├── utils/                    # Utility modules
└── lib/                      # Third-party libraries (excluded from processing)
```

## Prerequisites

### Environment Setup

1. **Python Environment**: Python 3.8 or higher

2. **Install Dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

3. **Environment Variables**: Create a `.env` file in the project root with the following variables:
   ```bash
   OPENAI_API_KEY=your_openai_api_key
   OPENAI_BASE_URL=your_openai_base_url
   ANTHROPIC_API_KEY=your_anthropic_api_key
   ANTHROPIC_OPENAI_BASE_URL=your_anthropic_base_url
   MS_OPENAI_BASE_URL=your_ms_openai_base_url
   MS_API_KEY=your_ms_api_key
   API2D_OPENAI_API_KEY=your_api2d_key
   API2D_OPENAI_BASE_URL=your_api2d_base_url
   OLLAMA_OPENAI_BASE_URL=your_ollama_base_url  # Optional
   VLLM_OPENAI_BASE_URL=your_vllm_base_url      # Optional
   ORIG_REPO=/path/to/original/repository       # Required for main experiments
   ```

   **Note**: `ORIG_REPO` should point to the original repository path used in the dataset. This is used for path remapping.

4. **Dataset**: Ensure `data/dataset.json` exists with the required structure (file paths and their requirements/context). The source repository is shipped as `repository.7z`; extract it under the project root as `repository/`, and set up a copy at the path given by `ORIG_REPO`.

5. **Test Mapping**: Ensure `data/test_map_cargo.pkl` exists, which maps source files to their test file paths.

6. **External Tools**:
   - **Foundry/Forge**: For Solidity compilation and testing
   - **Slither**: For static analysis (optional, used in some experiments)

## Running Experiments

### 1. Baseline Experiments

Run baseline agent implementations to generate comparison results:

#### DeepCode Baseline
```bash
python baseline_agent_deepcode.py
```

#### MetaGPT Baseline
```bash
python baseline_agent_metagpt.py
```

#### QwenAgent Baseline
```bash
python baseline_agent_qwenagent.py
```

#### GitHub Copilot Baseline
```bash
python baseline_agent_copilot.py
```

#### Vanillar LLM Baseline (Direct LLM API)
```bash
python baseline_rawmodel.py
```

#### Baseline Solidity Test (Original Files)
```bash
python baseline_sol_test.py
```
This script tests the original Solidity files from the dataset using Forge and Slither, providing a baseline for comparison. Results are stored in the `BaselineTest` table.

**Note**: Baseline results are stored in the database (`output/progress.db`) with agent-specific tracking tables. Each baseline script processes files from `data/dataset.json` and generates Solidity code according to the specified requirements.

### 2. SolAgent Main Experiment

Run the main SolAgent implementation:

```bash
python main_nopatch.py
```

This script:
- Uses `coding.yaml` for code generation agent configuration
- Uses `refine.yaml` for refinement agent configuration
- Stores results in `output/progress.db` using `ProgressTracker`
- Processes all files in the dataset and generates Solidity code
- Supports multiple models (configured in the script)
- Includes cost tracking and pause mechanisms

**Configuration Files**:
- `coding.yaml`: Defines the code generation agent (LLM model, system prompt, generation parameters)
- `refine.yaml`: Defines the refinement agent for code improvement

### 3. Ablation Studies

Run ablation experiments to study the impact of different components:

#### Ablation: No Forge Testing
```bash
python main_ablation_no_forge.py
```
This experiment removes Forge testing from the refinement process. Uses `refine_no_forge.yaml` configuration.

#### Ablation: No Slither Analysis
```bash
python main_ablation_no_slither.py
```
This experiment removes Slither static analysis from the refinement process. Uses `refine_no_slither.yaml` configuration.

#### Ablation: No Tools
```bash
python main_ablation_no_tools.py
```
This experiment removes all tools from the agent workflow. Uses `refine_no_tools.yaml` configuration.

**Note**: Ablation results are stored in `output/progress.db` using `ProgressTrackerAblation` in the `process_tracking_ablation` table with different `ablation_type` values:
- Type 2: No Forge
- Type 3: No Slither
- Type 4: No Tools

## Output and Results

All experiments store their results in SQLite database files located in the `output/` directory:

- **Database**: `output/progress.db`
- **Tables**: Different tracking tables for different experiment types
  - Baseline agents: Agent-specific tables
  - SolAgent: `process_tracking` table
  - Ablation studies: `process_tracking_ablation` table
  - Raw model baseline: `progress_tracker_rawmodel` table
  - Agent baselines: `progress_tracker_agent` table
  - Summary version: `process_tracking_summary` table

### Viewing Results

Results can be queried from the database or analyzed using the statistics scripts in the `stats/` directory:

```bash
# Run all statistics
python stats/run_all_stats.py

# Run specific statistics
python stats/rq1_statistics.py      # RQ1: Main comparison
python stats/rq2_ablation_statistics.py  # RQ2: Ablation study
python stats/rq3_distill_statistics.py  # RQ3: Distillation comparison
```

## Key Features

- **Multi-Agent Architecture**: Separate agents for code generation and refinement
- **Tool Integration**: File system operations, Forge testing, Slither analysis
- **Progress Tracking**: Comprehensive database tracking of all experiments

## Workflow Overview

### SolAgent Pipeline

1. **Code Generation**: The code agent reads requirements from the dataset and generates initial Solidity code
2. **Refinement**: The refine agent improves the generated code using:
   - Forge testing (compilation and unit tests)
   - Slither static analysis (vulnerability detection)
   - File system tools (reading context, writing code)
3. **Tracking**: All results are stored in the database with metrics.

### Model Configuration

Models are configured in the scripts themselves. To change models, edit the `models` list in `main.py` or the respective baseline/ablation scripts. Supported models include:
- OpenAI-compatible models (GPT-5, Qwen, etc.)
- Anthropic Claude models
- Local models via Ollama or vLLM

## Troubleshooting

1. **Import Errors**: Ensure all submodules in `lib/` are properly initialized (they are git submodules)
   ```bash
   git submodule update --init --recursive
   ```

2. **Database Locked**: If you encounter database lock errors, ensure no other processes are accessing `output/progress.db`

3. **API Errors**: Check your `.env` file and ensure API keys are correctly configured

4. **ORIG_REPO Not Set**: Ensure the `ORIG_REPO` environment variable is set to the correct repository path

5. **Forge/Slither Not Found**: Install Foundry and Slither if running experiments that require them:
   ```bash
   # Install Foundry
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   
   # Install Slither
   pip install slither-analyzer
   ```

## Distillation Training

This project supports knowledge distillation training to create smaller, efficient models based on the SolAgent results. The distillation process consists of two steps: data processing and model training.

### Prerequisites

1. **Alibaba SWIFT Framework**: Install SWIFT for training
   ```bash
   pip install ms-swift
   ```

2. **Completed Experiments**: Ensure you have run the main SolAgent experiments and have results in `output/progress.db`

### Step 1: Data Processing

Process the experimental results from the database to generate training datasets:

```bash
python z0train/data_processor.py
```

This script:
- Reads data from `output/progress.db` (`process_tracking` table)
- Filters by model whitelist (default: `["gpt-5.1", "claude-sonnet-4-5", "gpt-5-mini"]`)
- Filters by status (default: status >= 1, meaning completed experiments)
- Generates training datasets:
  - `z0train/output/processed_tracker.json` - From tracker table
  - `z0train/output/processed_mixed.json` - Combined dataset (tracker + summary, if summary data exists)

**Output Datasets**:
- `processed_tracker.json`: Training data from the main tracker table
- `processed_mixed.json`: Combined dataset including both tracker and summary data (if available)

**Configuration**:
- Edit `DEFAULT_MODEL_WHITELIST` in `z0train/data_processor.py` to change which models' data to include
- Modify `status_filter` in the `main()` function to change status filtering criteria

**Note**: You can use either `processed_tracker.json` or `processed_mixed.json` for training. The mixed dataset includes additional data from summary experiments if available.

### Step 2: Model Training

Train a distilled model using the processed data:

#### Stage 1: Right Truncation (First 4K tokens)

```bash
python z0train/train_sft_swift.py \
  --model_name_or_path Qwen/Qwen3-8B \
  --data_path z0train/output/processed_tracker.json \
  --output_dir z0train/output/stage1-right-4k \
  --stage 1 \
  --num_train_epochs 3 \
  --per_device_train_batch_size 1 \
  --gradient_accumulation_steps 2 \
  --learning_rate 2e-5 \
  --max_length 16384 \
  --gradient_checkpointing \
  --bf16
```

**Key Parameters**:
- `--model_name_or_path`: Base model to fine-tune (Qwen/Qwen3-8B, supports ModelScope model IDs)
- `--data_path`: Path to processed training data
- `--output_dir`: Directory to save checkpoints
- `--stage 1`: Right truncation mode (keeps first 4K tokens)
- `--max_length`: Maximum sequence length (16384 for 4K context)
- `--gradient_checkpointing`: Enable gradient checkpointing to save memory
- `--bf16`: Use bfloat16 precision for training

#### Stage 2: Left Truncation (Last 4K tokens, Continue from Stage 1)

After Stage 1 completes, continue training with left truncation:

```bash
python z0train/train_sft_swift.py \
  --model_name_or_path Qwen/Qwen3-8B \
  --data_path z0train/output/processed_tracker.json \
  --output_dir z0train/output/stage2-left-4k \
  --stage 2 \
  --stage1_checkpoint z0train/output/stage1-right-4k \
  --num_train_epochs 3 \
  --per_device_train_batch_size 1 \
  --gradient_accumulation_steps 2 \
  --learning_rate 2e-5 \
  --max_length 16384 \
  --gradient_checkpointing \
  --bf16
```

**Key Parameters**:
- `--stage 2`: Left truncation mode (keeps last 4K tokens)
- `--stage1_checkpoint`: Path to Stage 1 checkpoint directory

## Statistics and Analysis

After running experiments, use the statistics scripts to analyze results:

- `stats/rq1_statistics.py`: Compare SolAgent with baselines (Pass@1, Gas usage, Vulnerabilities)
- `stats/rq2_ablation_statistics.py`: Analyze ablation study results
- `stats/rq3_distill_statistics.py`: Compare distilled models
- `stats/ex_rq1_*.py`: Supplementary statistics (LOC, Token usage, Gas analysis)

## License

[Add your license information here]

## Citation

[Add citation information if applicable]
