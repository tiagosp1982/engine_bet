from motor_aposta.module.aposta.repositories.sorteio_repository import sorteio_repository
from motor_aposta.module.aposta.services.resultado_service import confere_resultado_por_concurso

def valida(id_tipo_jogo: int):
    sorteios = sorteio_repository.busca_sorteio_agrupado(id_tipo_jogo, "ASC")
    lista_resultado = []
    for s in sorteios:
        if int(s["nr_concurso"]) > 1:
            resultado = confere_resultado_por_concurso(id_tipo_jogo=id_tipo_jogo,
                                                    apostas=s["dezenas"],
                                                    nr_concurso=s["nr_concurso"] - 1)
            lista_resultado.append({
                    "Concurso": s["nr_concurso"],
                    "Acertos": resultado[0]
                }
            )

    return lista_resultado

nome_arquivo = f"C:\\Tiago\\resultado_x_concurso_anterior.txt"
resultado = valida(1)
try:
    with open(nome_arquivo, "w") as arquivo:  # Abre o arquivo para escrita
        for item in resultado:
            arquivo.write(str(item) + "\n")  # Converte o item para string e adiciona quebra de linha
    print(f"Lista gravada com sucesso em {nome_arquivo}")
except Exception as e:
    print(f"Ocorreu um erro ao gravar a lista: {e}")
            