import datetime
from decimal import Decimal
from pydantic import BaseModel


class ConcursoDTO(BaseModel):  
  id_tipo_jogo: int
  nr_concurso: int
  dt_concurso: datetime.date
  vl_acumulado: Decimal
  nr_proximo_concurso: int
  dt_proximo_concurso: datetime.date
  nr_ganhador: int
  