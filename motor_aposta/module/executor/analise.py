from motor_aposta.module.aposta.services.jogo_service import gera_jogo


id = 1
id_usuario = 1
qtde_aposta = 1
qtde_dezena_aposta = 16
somente_ausente = False
amarrar_jogos = False

jogo = gera_jogo(id=id,
                 id_usuario=id_usuario,
                 qtde_aposta=qtde_aposta,
                 qtde_dezena_aposta=qtde_dezena_aposta,
                 somente_ausente=somente_ausente,
                 amarrar_jogos=amarrar_jogos)
print(jogo)