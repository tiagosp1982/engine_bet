import json
from typing import Optional
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from atexit import register
from engine_bet.module.bet.repositories.parameter_repository import parameter_repository


class updater:
    def __init__(cls, **kwargs):
        super().__init__(**kwargs)
        register(cls)

    def list_result_external(route: str, contest: Optional[int] = None) -> dict:
        apiUrl: str
        apiUrl = parameter_repository.read_parameter()
        
        if (route == None):
            return None.__str__()
        else:
            apiUrl = apiUrl.__str__() + route.__str__()
            
        if (contest != None):
            apiUrl = apiUrl.__str__() + contest.__str__()

        retry_strategy = Retry(
            total=10,
            backoff_factor=1,
            status=500
        )

        adapter = HTTPAdapter(max_retries=retry_strategy)
        http = requests.Session()
        http.mount("https://", adapter)
        http.mount("http://", adapter)

        response = http.get(url=apiUrl, verify=False)
        if (response.status_code == 200):
            list = json.loads(response.text)
            return list
        else:
            return None