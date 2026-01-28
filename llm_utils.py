from urllib.parse import urlparse
from openai import OpenAI
from gpt5 import choose_model
from utils.config import Config

def create_client(model_name: str, stream: bool = True, platform: str = "openai"):
    
    # Create a dummy config to extract API settings
    code_config = Config.from_task("coding.yaml")
    code_config = choose_model(model_name, code_config, platform=platform)
    
    # Extract API key and base URL
    if code_config.llm.service == 'anthropic':
        api_key = getattr(code_config.llm, 'anthropic_api_key', 'vllm')
        base_url = getattr(code_config.llm, 'anthropic_base_url', 'http://localhost:8000/v1')
    else:
        api_key = getattr(code_config.llm, 'openai_api_key', 'vllm')
        base_url = getattr(code_config.llm, 'openai_base_url', 'http://localhost:8000/v1')
    model = getattr(code_config.llm, 'model', model_name)
    
    service_type = getattr(code_config.llm, 'service', 'openai')
    # Extract generation config
    generation_config = code_config.get('generation_config', {})

    # deepcode does not support streaming
    generation_config.stream = stream
    if stream is False and 'stream_options' in generation_config:
        del generation_config['stream_options']

    if service_type == 'anthropic':
        return create_anthropic_client(code_config, api_key, base_url, model, generation_config, service_type)
    else:
        return create_openai_client(code_config, api_key, base_url, model, generation_config, service_type)

def create_openai_client(code_config, api_key, base_url, model, generation_config, service_type):
    """Create OpenAI client based on model configuration"""
    import inspect
    
    if service_type == 'ollama':
        from ollama import Client as OllamaClient
        client_kwargs = {}
        if base_url:
            parsed = urlparse(base_url)
            host = f"{parsed.scheme}://{parsed.netloc}"
            client_kwargs['host'] = host
        client = OllamaClient(**client_kwargs)
        parameters = inspect.signature(client.chat).parameters
    else:
        client = OpenAI(api_key=api_key, base_url=base_url)
    
        # Get valid parameter keys from OpenAI API signature (do this once)
        parameters = inspect.signature(client.chat.completions.create).parameters

    valid_param_keys = set(parameters.keys())
    
    # Filter generation_config to only include valid parameters
    filtered_generation_config = {k: v for k, v in generation_config.items() if k in valid_param_keys}
    
    return client, model, filtered_generation_config, service_type

def create_anthropic_client(code_config, api_key, base_url, model, generation_config, service_type):
    from utils.llm.anthropic_llm import Anthropic
    client = Anthropic(code_config, api_key=api_key, base_url=base_url)
    
    return client, model, generation_config, service_type