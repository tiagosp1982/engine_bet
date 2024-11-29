class ConcursoDTO:
    def __init__(self, id_tipo_jogo, nr_concurso, dt_concurso, vl_acumulado, 
                 nr_proximo_concurso, dt_proximo_concurso, nr_ganhador) -> None:
        self.id_tipo_jogo = id_tipo_jogo
        self.nr_concurso = nr_concurso
        self.dt_concurso = dt_concurso
        self.vl_acumulado = vl_acumulado
        self.nr_proximo_concurso = nr_proximo_concurso
        self.dt_proximo_concurso = dt_proximo_concurso
        self.nr_ganhador = nr_ganhador
        self.lista_contest_dto = []
    
    def add(self,obj):
      assert isinstance(obj, ConcursoDTO)
      self.lista_contest_dto.append(obj)