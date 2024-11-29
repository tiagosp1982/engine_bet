from pydantic import BaseModel


class TipoJogoDTO(BaseModel):
    
    id_tipo_jogo: int

    nm_tipo_jogo: str

    qt_dezena_resultado: int

    qt_dezena_minima_aposta: int

    qt_dezena_maxima_aposta: int

    nm_route: str
        
    nr_concurso_max: int

    def add(self,obj):
      assert isinstance(obj,TipoJogoDTO)
      self.id_tipo_jogo = obj.id_tipo_jogo
      self.nm_route = obj.nm_route
      self.nm_tipo_jogo = obj.nm_tipo_jogo
      self.nr_concurso_max = obj.nr_concurso_max
      self.qt_dezena_maxima_aposta = obj.qt_dezena_maxima_aposta
      self.qt_dezena_minima_aposta = obj.qt_dezena_minima_aposta
      self.qt_dezena_resultado = obj.qt_dezena_resultado

    def factory(obj) -> dict:
        return TipoJogoDTO(id_tipo_jogo=obj[0][0],
                              nm_tipo_jogo=obj[0][1],
                              qt_dezena_resultado=obj[0][2],
                              qt_dezena_minima_aposta=obj[0][3],
                              qt_dezena_maxima_aposta=obj[0][4],
                              nm_route=obj[0][5], 
                              nr_concurso_max=obj[0][6])
