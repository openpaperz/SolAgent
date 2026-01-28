import time
from typing import Union, Dict, Any, Tuple, Generator
from openai import OpenAI

def call_openai_chat(
    client: OpenAI,
    model: str,
    messages: list,
    generation_config: dict = None,
    stream: bool = False,
    max_retries: int = 3,
    return_usage: bool = False
) -> Union[str, Tuple[str, Dict[str, int]], Generator]:
    """
    Call OpenAI Chat Completion API.

    Args:
        client: OpenAI client instance.
        model: Model name.
        messages: List of messages.
        generation_config: Configuration for generation (temperature, max_tokens, etc.).
        stream: Whether to stream the response.
        max_retries: Number of retries on failure.
        return_usage: Whether to return token usage (only for non-stream or if stream_options is supported).

    Returns:
        - If stream=True: Generator yielding chunks.
        - If stream=False and return_usage=False: Content string.
        - If stream=False and return_usage=True: Tuple (content, usage_dict).
    """
    if generation_config is None:
        generation_config = {}
    
    config = generation_config.copy()
    
    # Use stream from config if present, otherwise use argument
    if 'stream' in config:
        stream = config['stream']
    else:
        config['stream'] = stream
    
    # Add stream_options if streaming and usage requested (OpenAI specific)
    if stream and return_usage:
        config['stream_options'] = {'include_usage': True}

    for attempt in range(max_retries):
        try:
            response = client.chat.completions.create(
                model=model,
                messages=messages,
                **config
            )
            
            if stream:
                full_content = []
                usage = None
                start_time = time.time()
                try:
                    for chunk in response:
                        if chunk.choices and len(chunk.choices) > 0:
                            delta = chunk.choices[0].delta
                            if delta.content:
                                content = delta.content
                                full_content.append(content)
                                print(content, end="", flush=True)
                        
                        if hasattr(chunk, 'usage') and chunk.usage:
                            usage = chunk.usage
                except Exception as e:
                    print(f"\nError during streaming: {e}")
                finally:
                    elapsed = time.time() - start_time
                    print(f"\n[Streaming terminated in {elapsed:.2f} seconds]")
                    if chunk.choices and len(chunk.choices) > 0:
                        print(f"[Finish reason: {chunk.choices[0].finish_reason}]")
                        raise RuntimeError("Streaming interrupted unexpectedly")

                print() # Newline after stream
                
                resp = {
                    "choices": [
                        {"message": {"role": "assistant", "content": "".join(full_content)}}
                    ],
                    "usage": {
                        "prompt_tokens": usage.prompt_tokens if usage else 0,
                        "completion_tokens": usage.completion_tokens if usage else 0
                    }
                }
                return resp
            
            # Non-stream
            content = response.choices[0].message.content
            resp = {
                "choices": [
                    {"message": {"role": "assistant", "content": content}}
                ],
                "usage": {
                    "prompt_tokens": response.usage.prompt_tokens if response.usage else 0,
                    "completion_tokens": response.usage.completion_tokens if response.usage else 0
                }
            }
            return resp

        except Exception as e:
            print(f"OpenAI API call failed (attempt {attempt + 1}/{max_retries}): {e}")
            if attempt < max_retries - 1:
                time.sleep(2 ** attempt)
            else:
                raise e
    return None
