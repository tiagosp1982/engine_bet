from typing import Optional
from pydantic import BaseModel


class TipoJogoDTO(BaseModel):
    
    id_tipo_jogo: int

    nm_tipo_jogo: str

    qt_dezena_resultado: int

    qt_dezena_minima_aposta: int

    qt_dezena_maxima_aposta: int

    nm_route: str
        
    nr_concurso_max: Optional[int] = 0

    def add(self,obj):
      assert isinstance(obj,TipoJogoDTO)
      self.id_tipo_jogo = obj.id_tipo_jogo
      self.nm_route = obj.nm_route
      self.nm_tipo_jogo = obj.nm_tipo_jogo
      self.nr_concurso_max = obj.nr_concurso_max
      self.qt_dezena_maxima_aposta = obj.qt_dezena_maxima_aposta
      self.qt_dezena_minima_aposta = obj.qt_dezena_minima_aposta
      self.qt_dezena_resultado = obj.qt_dezena_resultado
