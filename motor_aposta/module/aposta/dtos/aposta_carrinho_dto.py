from typing import Optional
from pydantic import BaseModel


class ApostaCarrinhoDto(BaseModel):
    id_aposta: int = 1
    id_usuario: int
    id_tipo_jogo: int
    nr_concurso: int
    jogo: str
    repetidos: Optional[str] = None