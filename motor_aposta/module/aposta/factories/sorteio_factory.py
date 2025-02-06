from collections import defaultdict
from motor_aposta.module.aposta.dtos.sorteio_dto import SorteioDTO


class SorteioFactory():
    def ConverterDto(typeBetId, listsorteio) -> dict:
        obj = []
        for sorteio in listsorteio:
            item = SorteioDTO(nr_concurso=int(sorteio[0]),nr_sorteado=int(sorteio[1]))
            obj.append(item)
        return obj
    
    def ConverterParaLista(typeBetId, numeroContest, listsorteio) -> dict:
        list = []
        for sorteio in listsorteio:
            item = [typeBetId, numeroContest, sorteio]
            list.append(item)
        
        return list

    def ConverterListaSorteio(listsorteio) -> dict:
        agrupados = defaultdict(list)

        for sorteio in listsorteio:
            agrupados[sorteio.nr_concurso].append(int(sorteio.nr_sorteado))

        sorteios = []
        for resultado in agrupados.items():
            sorteios.append(resultado[1])

        return sorteios

    def ConverterListaSorteioId(listsorteio) -> dict:
        agrupados = defaultdict(list)

        for sorteio in listsorteio:
            agrupados[sorteio.nr_concurso].append(int(sorteio.nr_sorteado))

        sorteios = []
        for resultado in agrupados.items():
            item = [resultado[0], resultado[1]]
            sorteios.append(item)

        return sorteios

    def ConverterListStrParaListInt(numerosArray: str) -> dict:
        listaInt = []
        listaStr = numerosArray.split(',')
        for n in listaStr:
            listaInt.append(int(n))

        return listaInt