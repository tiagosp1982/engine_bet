from motor_aposta.module.aposta.services.jogo_service import gera_jogo_v1, gera_jogo_v2


# id = 1
# id_usuario = 1
# qtde_aposta = 1
# qtde_dezena_aposta = 17
# somente_ausente = False
# amarrar_jogos = False
# i = 0
# while i < qtde_aposta:
#     jogo = gera_jogo_v1(id=id,
#                     id_usuario=id_usuario,
#                     qtde_aposta=qtde_aposta,
#                     qtde_dezena_aposta=qtde_dezena_aposta,
#                     somente_ausente=somente_ausente,
#                     amarrar_jogos=amarrar_jogos
#                 )
#     i += 1
#     print(jogo)

id_tipo_jogo = 1
id_usuario = 1
qtde_aposta = 3
qtde_dezena_aposta = 16

jogos = gera_jogo_v2(id_tipo_jogo=id_tipo_jogo,
                    id_usuario=id_usuario,
                    qtde_aposta=qtde_aposta,
                    qtde_dezena_aposta=qtde_dezena_aposta,
                    analisa_simulacao=True,
                    grava_simulacao=True)

print(jogos)