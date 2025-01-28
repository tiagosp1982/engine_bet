import datetime
from pydantic import BaseModel


class UsuarioDTO(BaseModel):
    id_usuario: int

    nm_usuario: str

    ds_email: str

    ds_hashsenha: str

    dt_nascimento: datetime.date

    dt_cadastro: datetime.date

    ds_numero_celular: str