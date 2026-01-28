from typing import List, Dict, Any
from ms_agent.llm.utils import Message

def convert_to_messages(messages: List[Dict[str, Any]]) -> List[Message]:
    """
    Convert a list of message dictionaries to a list of Message objects.
    
    Args:
        messages: List of dictionaries, each containing at least 'role' and 'content'.
        
    Returns:
        List of Message objects.
    """
    return [Message(**msg) for msg in messages]