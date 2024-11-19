
from pydantic import BaseModel


class TipoJogoPremiacaoDto(BaseModel):
    id_tipo_jogo: int

    qt_dezena_acerto: int