from typing import Optional
from pydantic import BaseModel


class CombinacaoSorteioDto(BaseModel):
    id_tipo_jogo: int
    nr_qtde_dezena: int
    id_combinacao: int
    nr_concurso: int