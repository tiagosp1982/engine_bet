from concurrent.futures import ThreadPoolExecutor
from motor_aposta.module.aposta.dtos.combinacao_dto import CombinacaoDto
from motor_aposta.module.aposta.dtos.combinacao_sorteio_dto import CombinacaoSorteioDto
from motor_aposta.module.aposta.dtos.tipo_jogo_dto import TipoJogoDTO
from motor_aposta.module.aposta.dtos.tipo_jogo_premiacao_dto import TipoJogoPremiacaoDTO
from motor_aposta.module.aposta.factories.sorteio_factory import SorteioFactory
from motor_aposta.module.aposta.factories.combinacao_factory import CombinacaoFactory
from motor_aposta.module.aposta.repositories.combinacao_repository import combinacao_repository
from motor_aposta.module.aposta.repositories.sorteio_repository import sorteio_repository
from motor_aposta.module.aposta.repositories.tipo_jogo_repository import tipo_jogo_repository


def insere_combinacao(id_tipo_jogo: int, nr_qtde_dezena: int, combinacao: dict) -> bool:
    obj = CombinacaoDto(id_tipo_jogo=id_tipo_jogo,
                       nr_qtde_dezena=nr_qtde_dezena,
                       dezenas=str(combinacao).replace("(","").replace(")","")
                       )
    combinacao_repository.atualiza_combinacao(obj)

def gera_combinacao_sorteio(_id_tipo_jogo: int, _nr_dezena_combinacao: int) -> dict:
    tipo_jogo = tipo_jogo_repository.busca_tipo_jogo(_id_tipo_jogo)
    combinacoes = CombinacaoFactory.ConverteListaParaInt(combinacao_repository.busca_combinacao(
                                                            _id_tipo_jogo=_id_tipo_jogo,
                                                            _nr_qtde_dezena=_nr_dezena_combinacao)
                                                         )
    dados = sorteio_repository.lista_sorteio_combinacao(_id_tipo_jogo, _nr_dezena_combinacao)
    sorteios = SorteioFactory.ConverterListaSorteioId(dados)
    
    print('Gerando vinculo combinação sorteio, aguarde...')
    with ThreadPoolExecutor(max_workers=100) as executor:
        results = {executor.submit(atualiza_combinacao_sorteio, _id_tipo_jogo, _nr_dezena_combinacao, tipo_jogo, sorteios, combinacao): combinacao for combinacao in combinacoes}
    print('Vinculos gerados')

def valida_combinacao_improvavel(_id_tipo_jogo: int, _nr_qtde_dezena: int):
    premiacao = tipo_jogo_repository.busca_tipo_jogo_premiacao(id_tipo_jogo=_id_tipo_jogo)
    combinacoes = CombinacaoFactory.ConverteListaParaInt(combinacao_repository.busca_combinacao(
                                                            _id_tipo_jogo=_id_tipo_jogo,
                                                            _nr_qtde_dezena=_nr_qtde_dezena)
                                                         )
    print('Executando, aguarde...')
    with ThreadPoolExecutor(max_workers=90) as executor:
        results = {executor.submit(atualiza_combinacao_improvavel, _id_tipo_jogo, _nr_qtde_dezena, premiacao, combinacao): combinacao for combinacao in combinacoes}
    
    print('Atualização realizada com sucesso.')
        # for r in results:
        #     print(r.result())
    
            
def atualiza_combinacao_improvavel(_id_tipo_jogo: int, _nr_qtde_dezena: int, premiacao: TipoJogoPremiacaoDTO, combinacao):
    count = 0
    anterior = 0
    proximo = 0
    total = 0
    count += 1
    for c in combinacao[1]:
        proximo = c
        if (proximo == (anterior + 1)):
            total += 1
        anterior = c
    if (total >= premiacao.qt_dezena_acerto + 1):
        print(f'Atualizando combinação: {combinacao[0]}\n')
        combinacao_repository.atualiza_jogo_improvavel(id_tipo_jogo=_id_tipo_jogo,
                                                       nr_qtde_dezena=_nr_qtde_dezena,
                                                       id_combinacao=combinacao[0])

def atualiza_combinacao_sorteio(_id_tipo_jogo: int, _nr_dezena_combinacao: int, tipo_jogo: TipoJogoDTO, sorteios, combinacao):
    for sorteio in sorteios:
        resultado = [c for c in combinacao[1] if c in sorteio[1]]
        if (len(resultado) == tipo_jogo.qt_dezena_resultado):
            obj = CombinacaoSorteioDto(id_tipo_jogo=_id_tipo_jogo,
                                       nr_qtde_dezena=_nr_dezena_combinacao,
                                       id_combinacao=combinacao[0],
                                       nr_concurso=sorteio[0])
            combinacao_repository.atualizacao_combinacao_sorteio(obj)
    