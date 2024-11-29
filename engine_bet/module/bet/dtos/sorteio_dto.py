from collections import defaultdict


class SorteioDTO:
    def __init__(self, id_tipo_jogo=None, nr_concurso=None, nr_sorteado=None) -> None:
        self.id_tipo_jogo = id_tipo_jogo
        self.nr_concurso = nr_concurso
        self.nr_sorteado = nr_sorteado
        self.lista_sorteio_dto = []
    
    def add(self,obj):
      assert isinstance(obj, SorteioDTO)
      self.lista_sorteio_dto.append(obj)
    
    def factory(typeBetId, listsorteio) -> dict:
        obj = []
        for sorteio in listsorteio:
            item = SorteioDTO(nr_concurso=int(sorteio[0]),nr_sorteado=int(sorteio[1]))
            obj.append(item)
        return obj
    
    def factoryAny(typeBetId, numeroContest, listsorteio) -> dict:
        list = []
        for sorteio in listsorteio:
            item = [typeBetId, numeroContest, sorteio]
            list.append(item)
        
        return list

    def factorysorteioOnly(listsorteio) -> dict:
        agrupados = defaultdict(list)

        for sorteio in listsorteio:
            agrupados[sorteio.nr_concurso].append(int(sorteio.nr_sorteado))

        sorteios = []
        for resultado in agrupados.items():
            sorteios.append(resultado[1])

        return sorteios