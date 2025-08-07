import pandas as pd
import numpy as np
from tensorflow import keras
from keras.layers import LSTM, Dense
from keras.models import Sequential, load_model

from motor_aposta.module.aposta.dtos.tipo_jogo_dto import TipoJogoDTO
from motor_aposta.module.aposta.dtos.tipo_jogo_estrutura_dto import TipoJogoEstruturaDTO
from motor_aposta.module.aposta.repositories.sorteio_repository import sorteio_repository
from motor_aposta.module.aposta.repositories.tipo_jogo_repository import tipo_jogo_repository

class DadoCentroService():
    def __init__():
        pass

    def dado_centro(id_tipo_jogo: int, qtde_moldura: int, qtde_dezenas: int = 15) -> dict:
        tipo_jogo: TipoJogoDTO
        tipo_jogo_estrutura: TipoJogoEstruturaDTO

        tipo_jogo = tipo_jogo_repository.busca_tipo_jogo(id_tipo_jogo)
        tipo_jogo_estrutura = tipo_jogo_repository.busca_tipo_jogo_estrutura(id_tipo_jogo)
        sorteio_centro = sorteio_repository.busca_resultado_centro(id_tipo_jogo)

        # --- CONFIGURAÇÕES ---
        CONJUNTO_FIXO = [t.nr_estrutura_jogo for t in tipo_jogo_estrutura if t.flg_centro_moldura == 'C']
        JANELA = 5  # número de sorteios usados como entrada
        EPOCHS = 100
        QTDE_DEZENA_CENTRO = (tipo_jogo.qt_dezena_minima_aposta - qtde_moldura) + \
            (qtde_dezenas - tipo_jogo.qt_dezena_minima_aposta)
        LIMIAR = 0.5  # limite para considerar um número como "presente"

        # --- 1. Carregar o histórico ---
        df = pd.DataFrame(sorteio_centro)
        df['ds_dezenas'] = df['ds_dezenas'].apply(lambda x: list(map(int, x.split(','))))

        # --- 2. Transformar em vetores binários ---
        def sorteio_para_binario(sorteio, base):
            return [1 if n in sorteio else 0 for n in base]

        dados_binarios = np.array([sorteio_para_binario(s, CONJUNTO_FIXO) for s in df['ds_dezenas']])

        # --- 3. Criar sequências de treino ---
        X, y = [], []
        for i in range(JANELA, len(dados_binarios)):
            X.append(dados_binarios[i - JANELA:i])
            y.append(dados_binarios[i])
        X = np.array(X)
        y = np.array(y)

        # --- 4. Criar modelo LSTM ---
        modelo = Sequential()
        modelo.add(LSTM(64, activation='relu', input_shape=(X.shape[1], X.shape[2])))
        modelo.add(Dense(32, activation='relu'))
        modelo.add(Dense(len(CONJUNTO_FIXO), activation='sigmoid'))

        modelo.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])

        # --- 5. Treinar ---
        modelo.fit(X, y, epochs=EPOCHS, verbose=1)

        # --- 6. Prever próximo sorteio ---
        entrada = dados_binarios[-JANELA:]
        entrada = entrada.reshape((1, JANELA, len(CONJUNTO_FIXO)))
        saida = modelo.predict(entrada)[0]

        # --- 7. Converter os últimos 25 sorteios para comparação ---
        ultimos = set(
            tuple(sorted(sorteio_para_binario(s, CONJUNTO_FIXO))) for s in df['ds_dezenas'].iloc[-40:]
        )

        # --- 8. Tentar prever um conjunto inédito ---
        def gerar_previsao(valores_prob, limiar):
            return [CONJUNTO_FIXO[i] for i, prob in enumerate(valores_prob) if prob > limiar]

        # Tentar vários limiares, se necessário
        limiares_testados = [0.5, 0.45, 0.55, 0.6, 0.4]
        previsao_final = []

        for limiar_teste in limiares_testados:
            tentativa = gerar_previsao(saida, limiar_teste)
            tentativa_binaria = sorteio_para_binario(tentativa, CONJUNTO_FIXO)
            if tuple(tentativa_binaria) not in ultimos and len(tentativa) == QTDE_DEZENA_CENTRO:
                previsao_final = tentativa
                break

        # Se ainda assim for repetido, forçar escolha alternativa (menos prováveis)
        if not previsao_final:
            indices_ordenados = np.argsort(saida)[::-1]  # do mais provável ao menos
            for i in range(len(CONJUNTO_FIXO)):
                tentativa_indices = indices_ordenados[:i+4]  # mínimo de 4 números
                tentativa = sorted([CONJUNTO_FIXO[j] for j in tentativa_indices])
                tentativa_binaria = sorteio_para_binario(tentativa, CONJUNTO_FIXO)
                if tuple(tentativa_binaria) not in ultimos and len(tentativa) == QTDE_DEZENA_CENTRO:
                    previsao_final = tentativa
                    break

        # --- 9. Exibir resultado final ---
        return previsao_final

