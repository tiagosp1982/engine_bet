from typing import Optional
from pydantic import BaseModel


class SimulacaoDto(BaseModel):
    id_simulacao: int

    id_usuario: int

    id_tipo_jogo: int
    
    nr_concurso: int

    # nr_simulado: Optional[int]
