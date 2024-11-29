from engine_bet.module.bet.repositories.tipo_jogo_repository import tipo_jogo_repository
from engine_bet.module.external.api.updater import updater
from engine_bet.module.bet.repositories.concurso_repository import concurso_repository
from engine_bet.module.bet.dtos.concurso_dto import ConcursoDTO
from engine_bet.module.bet.dtos.sorteio_dto import SorteioDTO
from engine_bet.module.importer.dtos.update_sorteio_dto import UpdateSorteioDTO
from time import sleep


async def update_sorteio_all(_tipo_jogo: int) -> dict:
    lista_update_sorteio = []
    try:
        type_bet_dto = tipo_jogo_repository.busca_tipo_jogo(_tipo_jogo)
        
        concurso_base = type_bet_dto.nr_concurso_max
        valida_concurso = updater.lista_result_external(type_bet_dto.nm_route, None)
        ultimo_concurso = valida_concurso["numero"]

        while concurso_base <= ultimo_concurso:
            result = updater.lista_result_external(type_bet_dto.nm_route, concurso_base)
            if (result == None):
                sleep(60)
                result = updater.lista_result_external(type_bet_dto.nm_route, concurso_base)

            # dados do concurso
            valor = result["valorEstimadoProximoConcurso"]
            data = result["dataApuracao"]
            numero_concurso = result["numero"]
            data_proximo_concurso = result["dataProximoConcurso"]
            numero_proximo_concurso = result["numeroConcursoProximo"]
            ganhador = result["listaRateioPremio"][0]["numeroDeGanhadores"]
            id = type_bet_dto.id_tipo_jogo
            objconcurso = ConcursoDTO(id, numero_concurso, data, valor, numero_proximo_concurso, data_proximo_concurso, ganhador)
            concurso_repository.atualiza_concurso(objconcurso)
            
            # dados do resultados
            dezenas = result["listaDezenas"]
            objsorteio = SorteioDTO.factoryAny(id, numero_concurso, dezenas)
            concurso_repository.atualiza_sorteio(objsorteio)
            concurso_repository.atualiza_ciclo(id)
            obj = UpdateSorteioDTO(nm_tipo_jogo = type_bet_dto.nm_tipo_jogo, nr_concurso=numero_concurso, bl_importado=True)
            lista_update_sorteio.append(obj)
            concurso_base += 1
            print(f"Importado concurso: {numero_concurso}")

        return lista_update_sorteio
    except:
        return lista_update_sorteio[{"Erro": "Ocorreu um erro na atualização"}]