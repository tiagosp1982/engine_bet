class RaffleDto:
    def __init__(self, id_tipo_jogo=None, nr_concurso=None, nr_sorteado=None) -> None:
        self.id_tipo_jogo = id_tipo_jogo
        self.nr_concurso = nr_concurso
        self.nr_sorteado = nr_sorteado
        self.list_raffle_dto = []
    
    def add(self,obj):
      assert isinstance(obj, RaffleDto)
      self.list_raffle_dto.append(obj)
    
    def factory(typeBetId, numberContest, listRaffle) -> dict:
        obj = RaffleDto()
        for raffle in listRaffle:
            item = RaffleDto(typeBetId,numberContest,raffle)
            obj.add(item)
        return obj
    
    def factoryAny(typeBetId, numberContest, listRaffle) -> dict:
        list = []
        for raffle in listRaffle:
            item = [typeBetId, numberContest, raffle]
            list.append(item)
        
        return list