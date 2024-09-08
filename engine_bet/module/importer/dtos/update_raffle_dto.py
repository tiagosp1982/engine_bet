from pydantic import BaseModel


class UpdateRaffleDto(BaseModel):
    nm_tipo_jogo: str
    nr_concurso: int
    bl_importado: bool