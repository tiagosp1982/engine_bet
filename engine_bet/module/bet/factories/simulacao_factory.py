from collections import defaultdict
from engine_bet.module.bet.dtos.simulacao_dto import SimulacaoDto
from engine_bet.module.bet.dtos.simulacao_item_dto import SimulacaoItemDto


class SimulacaoFactory():
    def item(obj: SimulacaoDto, simulacao: dict) -> dict:
        list = []
        for n in simulacao:
            item = [obj.id_simulacao, obj.id_usuario, obj.id_tipo_jogo, obj.nr_concurso, n]
            list.append(item)
        
        return list

    def obj(list: dict) -> SimulacaoDto:
        return SimulacaoDto(id_simulacao=list[0][0],
                            id_usuario=list[0][1],
                            id_tipo_jogo=list[0][2],
                            nr_concurso=list[0][3])

    def simulationOnly(simulados: dict) -> dict:
        agrupados = defaultdict(list)

        for simulado in simulados:
            agrupados[simulado.nr_concurso].append(str(simulado.nr_simulado))

        sorteios = []
        for resultado in agrupados.items():
            sorteios.append(resultado[1])

        return sorteios

    def factoryItem(simulados) -> dict:
        obj = []
        for simulado in simulados:
            item = SimulacaoItemDto(nr_concurso=int(simulado[0]),nr_simulado=int(simulado[1]))
            obj.append(item)
        return obj