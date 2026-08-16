import os
from dotenv import load_dotenv

load_dotenv()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
OPENAI_BASE_URL = os.getenv("OPENAI_BASE_URL", "") # 501
ANTHROPIC_OPENAI_BASE_URL = os.getenv("ANTHROPIC_OPENAI_BASE_URL", "")
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
MS_OPENAI_BASE_URL =  os.getenv("MS_OPENAI_BASE_URL", "")
MS_OPENAI_API_KEY = os.getenv("MS_API_KEY", "")

API2D_OPENAI_API_KEY = os.getenv("API2D_OPENAI_API_KEY", "")
API2D_OPENAI_BASE_URL = os.getenv("API2D_OPENAI_BASE_URL", "")

OLLAMA_OPENAI_API_KEY = "ollama"
OLLAMA_OPENAI_BASE_URL = os.getenv("OLLAMA_OPENAI_BASE_URL", "")

VLLM_OPENAI_API_KEY = "vllm"
VLLM_OPENAI_BASE_URL = os.getenv("VLLM_OPENAI_BASE_URL", "")

anthropic_service_type_mapping = {
    "qwenagent": "openai",
}

def set_api_key(agent_config, api_key, base_url):
    agent_config.llm.openai_api_key = api_key
    agent_config.llm.openai_base_url = base_url

    print(base_url)

def set_api_key_anthropic(agent_config, api_key, base_url):
    del agent_config.llm.openai_api_key
    del agent_config.llm.openai_base_url
    agent_config.llm.anthropic_api_key = api_key
    agent_config.llm.anthropic_base_url = base_url

    print(base_url)

def gpt5_model(agent_config, platform="openai"):
    if platform == "openai":
        set_api_key(agent_config, api_key=OPENAI_API_KEY, base_url=OPENAI_BASE_URL)
    elif platform == "api2d":
        set_api_key(agent_config, api_key=API2D_OPENAI_API_KEY, base_url=API2D_OPENAI_BASE_URL)
    # agent_config.llm.openai_api_key = OPENAI_API_KEY
    # agent_config.llm.openai_base_url = OPENAI_BASE_URL # 501

    agent_config.llm.model = "gpt-5-mini" # "gpt-5", gpt-5-nano, gpt-5-mini
    agent_config["generation_config"] = {
        k: v for k, v in agent_config["generation_config"].items()
        if k not in ["top_k", "top_p", "temperature", "max_tokens"]
    }
    agent_config.generation_config["max_completion_tokens"] = 30000 #16384
    agent_config.generation_config["extra_body"] = None
    agent_config.generation_config["reasoning_effort"] = None #"minimal"

    return agent_config

def api_gpt5_model(agent_config, model_name: str = "qwen3-coder_30b", platform="openai"):
    if platform == "openai":
        set_api_key(agent_config, api_key=OPENAI_API_KEY, base_url=OPENAI_BASE_URL)
    elif platform == "api2d":
        set_api_key(agent_config, api_key=API2D_OPENAI_API_KEY, base_url=API2D_OPENAI_BASE_URL)

    agent_config.llm.service = "openai"
    agent_config.llm.model = model_name
    agent_config["generation_config"] = {
        "max_completion_tokens": 50000,
        "stream": True,
    }

    return agent_config

def vllm_qwen3_model(agent_config, model_name: str = "qwen3-coder_30b"):
    set_api_key(agent_config, VLLM_OPENAI_API_KEY, VLLM_OPENAI_BASE_URL)

    agent_config.llm.service = "openai"
    agent_config.llm.model = model_name
    agent_config["generation_config"] = {
        "max_completion_tokens": 30000,
        "temperature": 1.0,
        "top_p": 0.6,
        "extra_body":{
            "enable_thinking": False
        },
        # "stream": True,
    }

    return agent_config

def vllm_qwen3_model_instruct(agent_config, model_name: str = "qwen3-coder_30b"):
    set_api_key(agent_config, VLLM_OPENAI_API_KEY, VLLM_OPENAI_BASE_URL)

    agent_config.llm.service = "openai"
    agent_config.llm.model = model_name
    agent_config["generation_config"] = {
        "max_completion_tokens": 16*1024,
        "temperature": 1.0,
        "top_p": 0.6,
        # "extra_body":{
        #     "enable_thinking": False
        # },
        # "stream": True,
    }

    return agent_config

def api_qwen3_model(agent_config, model_name: str = "qwen3-coder_30b"):
    set_api_key(agent_config, MS_OPENAI_API_KEY, MS_OPENAI_BASE_URL)

    agent_config.llm.service = "openai"
    agent_config.llm.model = model_name
    agent_config["generation_config"] = {
        "max_completion_tokens": 30000,
        # "max_tokens": 50000,
        "temperature": 1.0,
        "top_p": 0.6,
        "extra_body":{
            "enable_thinking": False
        },
        "stream": True,
    }

    return agent_config


def claude_openai_model(agent_config, model_name: str = "qwen3-coder_30b"):
    set_api_key(agent_config, OPENAI_API_KEY, OPENAI_BASE_URL)

    agent_config.llm.service = "openai"
    agent_config.llm.model = model_name
    agent_config["generation_config"] = {
        "max_tokens": 30000,
        "temperature": 1.0,
        # "top_p": 0.6,
    }

    return agent_config

def api_claude_model(agent_config, model_name: str = "qwen3-coder_30b", platform="anthropic"):
    if platform == "openai":
        set_api_key(agent_config, OPENAI_API_KEY, OPENAI_BASE_URL)
        # agent_config["generation_config"] = {
        #     "max_completion_tokens": 30000,
        #     # "stream": True,
        # }
    elif platform == "anthropic":
        set_api_key_anthropic(agent_config, ANTHROPIC_API_KEY, ANTHROPIC_OPENAI_BASE_URL)

    agent_config["generation_config"] = {
        "max_tokens": 50000, #30000,
        "temperature": 1.0,
        # "top_p": 0.6,
        # "stream": True,
    }

    agent_config.llm.service = platform
    agent_config.llm.model = model_name

    return agent_config

def claude_model(agent_config):
    # agent_config.llm.openai_api_key = OPENAI_API_KEY
    # agent_config.llm.openai_base_url = OPENAI_BASE_URL # 501
    #
    del agent_config.llm.openai_api_key
    del agent_config.llm.openai_base_url
    agent_config.llm.anthropic_api_key = OPENAI_API_KEY
    agent_config.llm.anthropic_base_url = OPENAI_BASE_URL # 501

    agent_config.llm.service = "anthropic"
    agent_config.llm.model = "claude-sonnet-4" # claude-sonnet-4-5, claude-sonnet-4
    agent_config["generation_config"] = {
        k: v for k, v in agent_config["generation_config"].items()
        if k not in ["top_k", "max_completion_tokens"]
    }
    agent_config.generation_config["top_p"] = 0.6
    agent_config.generation_config["temperature"] = 0.2
    # agent_config.generation_config["top_k"] = 20
    agent_config.generation_config["max_tokens"] = 16384
    del agent_config.generation_config["extra_body"]

    return agent_config


def gpt4o_model(agent_config):
    agent_config.llm.openai_api_key = OPENAI_API_KEY
    agent_config.llm.openai_base_url = OPENAI_BASE_URL # 501
    # agent_config.llm.openai_base_url = "https://momi.qq.com/v1" #400

    agent_config.llm.model = "gpt-4o-mini" # "gpt-4o" #
    agent_config["generation_config"] = {
        k: v for k, v in agent_config["generation_config"].items()
        if k not in ["max_completion_tokens"]
    }
    agent_config.generation_config["top_p"] = 0.6
    agent_config.generation_config["temperature"] = 0.2
    agent_config.generation_config["top_k"] = 20
    agent_config.generation_config["max_tokens"] = 16384
    agent_config.generation_config["extra_body"] = None

    return agent_config

def qwen3_model(agent_config, model_name: str = "qwen2.5-coder:32b-instruct"):
    set_api_key(agent_config, OLLAMA_OPENAI_API_KEY, OLLAMA_OPENAI_BASE_URL)

    agent_config.llm.service = "ollama"
    # not work: gpt-oss:20b; qwen3-coder:30b
    # code work, refine fail: qwen2.5-coder:32b

    # qwen3:32b #"qwen3:30b-instruct" #"qwen3:235b-instruct"
    # "qwen3:30b-instruct" is calling the same tool always
    # qwen2.5-coder:32b-instruct
    # qwen3-coder:480b
    agent_config.llm.model = model_name
    agent_config["generation_config"] = {
        "options": {
            "top_p": 0.6,
            # "temperature": 0.3, # higher = more random
            # "max_tokens": 128000,
            "num_ctx": 65536*2-1, #32764,

            # "max_completion_tokens": 16384,
            "num_predict": 30000, #16384,
            # "stop": ["```", "contract", "function"],
        },
        "think": False,
        "stream": False,
    }

    return agent_config

def vllm_qwen3coder_model(agent_config, model_name: str = "qwen3-coder_30b"):
    set_api_key(agent_config, VLLM_OPENAI_API_KEY, VLLM_OPENAI_BASE_URL)

    agent_config.llm.service = "openai"
    agent_config.llm.model = model_name
    agent_config["generation_config"] = {
        "max_completion_tokens": 30000,
        "temperature": 1.0,
        "top_p": 0.6,
    }

    return agent_config

# def api_qwen3_model(agent_config, model_name: str = "qwen3-coder_30b"):
#     set_api_key(agent_config, OPENAI_API_KEY, OPENAI_BASE_URL)

#     agent_config.llm.service = "openai"
#     agent_config.llm.model = model_name
#     agent_config["generation_config"] = {
#         "max_completion_tokens": 30000,
#         "temperature": 1.0,
#         "top_p": 0.6,
#     }

#     return agent_config

def api_deepseek_model(agent_config, model_name: str = "qwen3-coder_30b", max_tokens: int = None):
    set_api_key(agent_config, OPENAI_API_KEY, OPENAI_BASE_URL)

    agent_config.llm.service = "openai"
    agent_config.llm.model = model_name
    agent_config["generation_config"] = {
        "max_tokens": max_tokens if max_tokens is not None else 30000,
        "temperature": 1.0,
        "top_p": 0.6,
    }

    return agent_config

def gptoss_model(agent_config):
    set_api_key(agent_config, OLLAMA_OPENAI_API_KEY, OLLAMA_OPENAI_BASE_URL)

    agent_config.llm.service = "ollama"
    # not work: gpt-oss:20b; qwen3-coder:30b
    # code work, refine fail: qwen2.5-coder:32b

    # qwen3:32b #"qwen3:30b-instruct" #"qwen3:235b-instruct"
    # "qwen3:30b-instruct" is calling the same tool always
    # qwen2.5-coder:32b-instruct
    agent_config.llm.model = "gpt-oss:120b" #"qwen2.5-coder:32b" # "gpt-oss:120b"
    agent_config["generation_config"] = {
        "options": {
            # "top_p": 0.6,
            # "temperature": 0.3, # higher = more random
            # "max_tokens": 128000,
            "num_ctx": 65536*2-1, #32764,

            # "max_completion_tokens": 16384,
            "num_predict": 16384,
            # "stop": ["```", "contract", "function"],
        },
        "think": False,
        "stream": False,

    }

    return agent_config

def phi_model(agent_config):
    set_api_key(agent_config, OLLAMA_OPENAI_API_KEY, OLLAMA_OPENAI_BASE_URL)

    agent_config.llm.service = "ollama"

    agent_config.llm.model = "phi4-mini:3.8b" #
    agent_config["generation_config"] = {
        "options": {
            # "top_p": 0.6,
            # "temperature": 0.3, # higher = more random
            # "max_tokens": 128000,
            "num_ctx": 65536*2-1, #32764,

            # "max_completion_tokens": 16384,
            "num_predict": 16384*2,
            # "stop": ["```", "contract", "function"],
        },
        # "think": False,
        "stream": False,
    }

    return agent_config


def choose_model(model_name: str, agent_config, platform: str = "openai"):
    """
    Unified model selection function.

    Args:
        model_name: Name of the model to use. Supported values:
                    'gpt5', 'gpt4o', 'claude', 'qwen3', 'qwen3-coder_30b', 'gptoss', 'phi'
        agent_config: Agent configuration object to modify
        platform: Platform to use for gpt5 (default: 'openai')

    Returns:
        Modified agent_config with the selected model settings

    Raises:
        ValueError: If model_name is not recognized
    """
    # model_name_lower = model_name.lower()

    # if model_name_lower.startswith('qwen') and model_name_lower not in ['qwen3-coder_30b']:
    #     model_name_lower = 'qwen'

    model_map = {
        'gpt-5-mini': lambda cfg: api_gpt5_model(cfg, model_name=model_name, platform=platform),
        'gpt-5.1': lambda cfg: api_gpt5_model(cfg, model_name=model_name, platform=platform),
        'gpt-5.2': lambda cfg: api_gpt5_model(cfg, model_name=model_name, platform=platform),
        'mimo-v2.5-pro': lambda cfg: api_gpt5_model(cfg, model_name=model_name, platform=platform),
        # 'qwen': lambda cfg: qwen3_model(cfg, model_name=model_name),
        'qwen3-coder_30b': lambda cfg: vllm_qwen3coder_model(cfg, model_name=model_name),
        'Qwen/Qwen3-30B-A3B-Instruct-2507': lambda cfg: api_qwen3_model(cfg, model_name=model_name),
        'gpt4o': gpt4o_model,
        'claude-sonnet-4-5': lambda cfg: api_claude_model(cfg, model_name=model_name, platform=platform),
        'gptoss': gptoss_model,
        'phi': phi_model,
        'deepseek-v3-1-vol': lambda cfg: api_deepseek_model(cfg, model_name=model_name),
        'deepseek-speciale': lambda cfg: api_deepseek_model(cfg, model_name=model_name),
        'deepseek-chat': lambda cfg: api_deepseek_model(cfg, model_name=model_name, max_tokens=8192),
        'gemini-3-pro-preview': lambda cfg: api_deepseek_model(cfg, model_name=model_name),
        'grok-4-latest': lambda cfg: api_deepseek_model(cfg, model_name=model_name),

        "Qwen/Qwen3-8B": lambda cfg: api_qwen3_model(cfg, model_name=model_name),
        "Qwen/Qwen3-32B": lambda cfg: api_qwen3_model(cfg, model_name=model_name),
        "Qwen/Qwen3-4B-Instruct-2507": lambda cfg: api_qwen3_model(cfg, model_name=model_name),

        "Qwen/Qwen3-8B-v": lambda cfg: vllm_qwen3_model(cfg, model_name=model_name),
        "solagent-4k-tracker-v1": lambda cfg: vllm_qwen3_model(cfg, model_name=model_name),
        "solagent-4k-mixed-v1": lambda cfg: vllm_qwen3_model(cfg, model_name=model_name),
        "solagent-4k-tracker-v2": lambda cfg: vllm_qwen3_model(cfg, model_name=model_name),
        "solagent-4k-mixed-v2": lambda cfg: vllm_qwen3_model(cfg, model_name=model_name),

        "Qwen/Qwen3-4B-Instruct-2507-v": lambda cfg: vllm_qwen3_model_instruct(cfg, model_name=model_name),
        "solagent-20k-tracker-4b-instruct": lambda cfg: vllm_qwen3_model_instruct(cfg, model_name=model_name),
        "solagent-20k-mixed-4b-instruct": lambda cfg: vllm_qwen3_model_instruct(cfg, model_name=model_name),
        "solagent-20k-tracker-4b-instruct-v2": lambda cfg: vllm_qwen3_model_instruct(cfg, model_name=model_name),
        "solagent-20k-mixed-4b-instruct-v2": lambda cfg: vllm_qwen3_model_instruct(cfg, model_name=model_name),
        "solagent-256k-tracker-4b-instruct": lambda cfg: vllm_qwen3_model_instruct(cfg, model_name=model_name),
        "solagent-256k-mixed-4b-instruct": lambda cfg: vllm_qwen3_model_instruct(cfg, model_name=model_name),
        "solagent-64k-tracker-4b-instruct-lora": lambda cfg: vllm_qwen3_model_instruct(cfg, model_name=model_name),
        "solagent-64k-tracker-4b-instruct-lora-last": lambda cfg: vllm_qwen3_model_instruct(cfg, model_name=model_name),
    }

    if model_name in model_map:
        # Apply model-specific configuration
        agent_config = model_map[model_name](agent_config)
        # Ensure a generous timeout for long generations across all models
        try:
            if hasattr(agent_config, "generation_config"):
                agent_config.generation_config["timeout"] = 3600
                if agent_config.generation_config.get('stream', False):
                    agent_config.generation_config['stream_options'] = {'include_usage': True}

        except Exception:
            # Be resilient if agent_config structure differs
            pass

        return agent_config
    else:
        # Fallback to gpt5 as default, or raise error
        available_models = ', '.join(list(model_map.keys()) + ['qwen3-coder_30b'])
        raise ValueError(
            f"Unknown model name: '{model_name}'. "
            f"Available models: {available_models}"
        )


def get_model_display_name(agent_config) -> str:
    """
    Extract a human-readable model name from the agent config.

    Args:
        agent_config: Agent configuration object

    Returns:
        Model display name string
    """
    if hasattr(agent_config, 'llm') and hasattr(agent_config.llm, 'model'):
        return agent_config.llm.model
    return "unknown"