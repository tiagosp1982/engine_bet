import datetime
from typing import Optional
from pydantic import BaseModel

class ApostaDto(BaseModel):
    id_aposta: int = 1
    id_usuario: int
    id_tipo_jogo: int
    nr_concurso: int
    dt_aposta: Optional[datetime.date] = datetime.date.today()