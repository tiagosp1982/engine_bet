from typing import Optional
from pydantic import BaseModel


class CombinacaoDto(BaseModel):
    id_tipo_jogo: int
    nr_qtde_dezena: int
    dezenas: str

class CombinacaoFormatadaDto(BaseModel):
    id_combinacao: int
    nr_dezenas: str