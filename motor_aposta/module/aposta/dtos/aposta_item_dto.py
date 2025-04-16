from pydantic import BaseModel

class ApostaItemDto(BaseModel):
    id_aposta: int
    id_usuario: int
    id_tipo_jogo: int
    nr_concurso: int
    nr_aposta: int