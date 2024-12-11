
from pydantic import BaseModel


class TipoJogoPremiacaoDTO(BaseModel):
    id_tipo_jogo: int

    qt_dezena_acerto: int