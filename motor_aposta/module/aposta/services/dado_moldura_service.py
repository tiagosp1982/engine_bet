import os
import warnings

from typing import Optional
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'
warnings.filterwarnings("ignore")

from motor_aposta.module.aposta.dtos.tipo_jogo_dto import TipoJogoDTO
from motor_aposta.module.aposta.repositories.sorteio_repository import sorteio_repository
import pandas as pd
import numpy as np
import tensorflow as tf
from keras.layers import LSTM, Dense
from keras.models import Sequential
import random

from motor_aposta.module.aposta.dtos.tipo_jogo_estrutura_dto import TipoJogoEstruturaDTO
from motor_aposta.module.aposta.repositories.tipo_jogo_repository import tipo_jogo_repository

class DadoMolduraService():
    def __init__():
        pass

    def dado_moldura(id_tipo_jogo: int, qtde_dezenas: int = 15) -> Optional[dict]:
        tipo_jogo: TipoJogoDTO
        tipo_jogo_estrutura: TipoJogoEstruturaDTO

        tipo_jogo = tipo_jogo_repository.busca_tipo_jogo(id_tipo_jogo)
        tipo_jogo_estrutura = tipo_jogo_repository.busca_tipo_jogo_estrutura(id_tipo_jogo)
        sorteio_moldura = sorteio_repository.busca_resultado_moldura(id_tipo_jogo)

        # Configurações
        CONJUNTO_BASE = [t.nr_estrutura_jogo for t in tipo_jogo_estrutura if t.flg_centro_moldura == 'M']
        TAMANHO_ENTRADA = 5
        SORTEIO_MIN = 10 + (qtde_dezenas - tipo_jogo.qt_dezena_minima_aposta)
        SORTEIO_MAX = 11 + (qtde_dezenas - tipo_jogo.qt_dezena_minima_aposta)
        EPOCHS = 100

        # 1. Carregar e preparar os dados
        df = pd.DataFrame(sorteio_moldura)
        df['ds_dezenas'] = df['ds_dezenas'].apply(lambda x: list(map(int, x.split(','))))

        def dezenas_para_binario(dezenas, conjunto):
            return [1 if numero in dezenas else 0 for numero in conjunto]

        dados_binarios = np.array([dezenas_para_binario(linha, CONJUNTO_BASE) for linha in df['ds_dezenas']])

        X, y = [], []
        for i in range(len(dados_binarios) - TAMANHO_ENTRADA):
            X.append(dados_binarios[i:i+TAMANHO_ENTRADA])
            y.append(dados_binarios[i+TAMANHO_ENTRADA])
        X, y = np.array(X), np.array(y)

        # 2. Criar e treinar o modelo
        model = Sequential()
        model.add(LSTM(64, input_shape=(X.shape[1], X.shape[2]), activation='relu'))
        model.add(Dense(len(CONJUNTO_BASE), activation='sigmoid'))
        model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])
        model.fit(X, y, epochs=EPOCHS, verbose=1)

        # 3. Prever próximo sorteio
        entrada = np.array([dados_binarios[-TAMANHO_ENTRADA:]])
        pred = model.predict(entrada)[0]

        # 4. Ordenar dezenas pela probabilidade prevista
        dezenas_ordenadas = [x for _, x in sorted(zip(pred, CONJUNTO_BASE), reverse=True)]

        # 5. Obter todos os conjuntos sorteados anteriores
        historico_sets = [set(dez) for dez in df['ds_dezenas']]

        # 6. Gerar conjunto previsto que nunca foi sorteado
        def gerar_conjunto_valido():
            for _ in range(1000):  # tenta até 1000 vezes
                tamanho = random.randint(SORTEIO_MIN, SORTEIO_MAX)
                candidato = set(dezenas_ordenadas[:tamanho])
                if candidato not in historico_sets:
                    return sorted(candidato)
            return None

        resultado = gerar_conjunto_valido()

        # 7. Resultado
        if resultado:
            return resultado
        return None
