import json
from typing import Optional
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from atexit import register
from engine_bet.module.bet.repositories.parametro_repository import parametro_repository


class updater:
    def __init__(cls, **kwargs):
        super().__init__(**kwargs)
        register(cls)

    def lista_result_external(route: str, concurso: Optional[int] = None) -> dict:
        apiUrl: str
        apiUrl = parametro_repository.busca_parametro()
        
        if (route == None):
            return None.__str__()
        else:
            apiUrl = apiUrl.__str__() + route.__str__()
            
        if (concurso != None):
            apiUrl = apiUrl.__str__() + concurso.__str__()

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