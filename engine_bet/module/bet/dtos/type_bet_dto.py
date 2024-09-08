class TypeBetDto:
    def __init__(self, id_tipo_jogo=None, nm_tipo_jogo=None, qt_dezena_resultado=None, qt_dezena_minima_aposta=None, 
                 qt_dezena_maxima_aposta=None, nm_route=None, nr_concurso_max=None):
        self.id_tipo_jogo = id_tipo_jogo
        self.nm_tipo_jogo = nm_tipo_jogo
        self.qt_dezena_resultado = qt_dezena_resultado
        self.qt_dezena_minima_aposta = qt_dezena_minima_aposta
        self.qt_dezena_maxima_aposta = qt_dezena_maxima_aposta
        self.nm_route = nm_route
        self.nr_concurso_max = nr_concurso_max
        self.list_type_bet_dto = []

    def add(self,obj):
      assert isinstance(obj,TypeBetDto)
      self.list_type_bet_dto.append(obj)

    def factory(listObject) -> dict:
        obj = TypeBetDto()
        for t in listObject:
            item = TypeBetDto(t[0], t[1], t[2], t[3], t[4], t[5], t[6])
            obj.add(item)

        return obj
