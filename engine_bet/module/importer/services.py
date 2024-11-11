from engine_bet.module.bet.repositories.type_bet_repository import type_bet_repository
from engine_bet.module.external.api.updater import updater
from engine_bet.module.bet.repositories.contest_repository import contest_repository
from engine_bet.module.bet.dtos.contest_dto import ContestDto
from engine_bet.module.bet.dtos.raffle_dto import RaffleDto
from engine_bet.module.importer.dtos.update_raffle_dto import UpdateRaffleDto
from time import sleep


async def update_raffle_all(_tipo_jogo: int) -> dict:
    list_update_raffle = []
    try:
        type_bet_dto = type_bet_repository.read_type_bet(_tipo_jogo)
        
        concurso_base = type_bet_dto.nr_concurso_max
        valida_concurso = updater.list_result_external(type_bet_dto.nm_route, None)
        ultimo_concurso = valida_concurso["numero"]

        while concurso_base <= ultimo_concurso:
            result = updater.list_result_external(type_bet_dto.nm_route, concurso_base)
            if (result == None):
                sleep(60)
                result = updater.list_result_external(type_bet_dto.nm_route, concurso_base)

            # dados do concurso
            valor = result["valorEstimadoProximoConcurso"]
            data = result["dataApuracao"]
            numero_concurso = result["numero"]
            data_proximo_concurso = result["dataProximoConcurso"]
            numero_proximo_concurso = result["numeroConcursoProximo"]
            ganhador = result["listaRateioPremio"][0]["numeroDeGanhadores"]
            id = type_bet_dto.id_tipo_jogo
            objContest = ContestDto(id, numero_concurso, data, valor, numero_proximo_concurso, data_proximo_concurso, ganhador)
            contest_repository.write_data_contest(objContest)
            
            # dados do resultados
            dezenas = result["listaDezenas"]
            objRaffle = RaffleDto.factoryAny(id, numero_concurso, dezenas)
            contest_repository.write_data_raffle(objRaffle)
            contest_repository.update_cicle_data(id)
            obj = UpdateRaffleDto(nm_tipo_jogo = type_bet_dto.nm_tipo_jogo, nr_concurso=numero_concurso, bl_importado=True)
            list_update_raffle.append(obj)
            concurso_base += 1
            print(f"Importado concurso: {numero_concurso}")

        return list_update_raffle
    except:
        return list_update_raffle[{"Erro": "Ocorreu um erro na atualização"}]