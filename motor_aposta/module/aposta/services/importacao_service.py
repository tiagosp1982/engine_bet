from motor_aposta.module.aposta.factories.sorteio_factory import SorteioFactory
from motor_aposta.module.aposta.repositories.tipo_jogo_repository import tipo_jogo_repository
from motor_aposta.module.caixa.api.atualiza_resultado import atualiza_resultado
from motor_aposta.module.aposta.repositories.concurso_repository import concurso_repository
from motor_aposta.module.aposta.dtos.concurso_dto import ConcursoDTO
from motor_aposta.module.aposta.dtos.importacao_dto import ImportacaoDTO
from time import sleep


async def importa_resultado_por_tipo_jogo(_tipo_jogo: int) -> dict:
    lista_update_sorteio = []
    try:
        tipo_jogo_dto = tipo_jogo_repository.busca_tipo_jogo(_tipo_jogo)
        
        concurso_base = tipo_jogo_dto.nr_concurso_max
        valida_concurso = atualiza_resultado.lista_resultado(tipo_jogo_dto.nm_route, None)
        ultimo_concurso = valida_concurso["numero"]

        while concurso_base <= ultimo_concurso:
            result = atualiza_resultado.lista_resultado(tipo_jogo_dto.nm_route, concurso_base)
            if (result == None):
                sleep(60)
                result = atualiza_resultado.lista_resultado(tipo_jogo_dto.nm_route, concurso_base)

            # dados do concurso
            valor = result["valorEstimadoProximoConcurso"]
            data = result["dataApuracao"]
            numero_concurso = result["numero"]
            data_proximo_concurso = result["dataProximoConcurso"]
            numero_proximo_concurso = result["numeroConcursoProximo"]
            ganhador = result["listaRateioPremio"][0]["numeroDeGanhadores"]
            id = tipo_jogo_dto.id_tipo_jogo
            objconcurso = ConcursoDTO(id, numero_concurso, data, valor, numero_proximo_concurso, data_proximo_concurso, ganhador)
            concurso_repository.atualiza_concurso(objconcurso)
            
            # dados do resultados
            dezenas = result["listaDezenas"]
            objsorteio = SorteioFactory.ConverterParaLista(id, numero_concurso, dezenas)
            concurso_repository.atualiza_sorteio(objsorteio)
            concurso_repository.atualiza_ciclo(id)
            obj = ImportacaoDTO(nm_tipo_jogo = tipo_jogo_dto.nm_tipo_jogo,
                                nr_concurso=numero_concurso,
                                bl_importado=True)
            lista_update_sorteio.append(obj)
            concurso_base += 1
            print(f"Importado concurso: {numero_concurso}")

        return lista_update_sorteio
    except:
        return lista_update_sorteio[{"Erro": "Ocorreu um erro na atualização"}]