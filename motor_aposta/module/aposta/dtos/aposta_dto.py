from pydantic import BaseModel

class ApostaDto(BaseModel):
    def __init__(self, lista_aposta: list):
        self.aposta = [item for item in lista_aposta]
    
    apostas: list[int]