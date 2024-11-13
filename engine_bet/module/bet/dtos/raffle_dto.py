from collections import defaultdict


class RaffleDto:
    def __init__(self, id_tipo_jogo=None, nr_concurso=None, nr_sorteado=None) -> None:
        self.id_tipo_jogo = id_tipo_jogo
        self.nr_concurso = nr_concurso
        self.nr_sorteado = nr_sorteado
        self.list_raffle_dto = []
    
    def add(self,obj):
      assert isinstance(obj, RaffleDto)
      self.list_raffle_dto.append(obj)
    
    def factory(typeBetId, listRaffle) -> dict:
        obj = []
        for raffle in listRaffle:
            item = RaffleDto(nr_concurso=int(raffle[0]),nr_sorteado=int(raffle[1]))
            obj.append(item)
        return obj
    
    def factoryAny(typeBetId, numberContest, listRaffle) -> dict:
        list = []
        for raffle in listRaffle:
            item = [typeBetId, numberContest, raffle]
            list.append(item)
        
        return list

    def factoryRaffleOnly(listRaffle) -> dict:
        agrupados = defaultdict(list)

        for raffle in listRaffle:
            agrupados[raffle.nr_concurso].append(int(raffle.nr_sorteado))

        sorteios = []
        for resultado in agrupados.items():
            sorteios.append(resultado[1])

        return sorteios