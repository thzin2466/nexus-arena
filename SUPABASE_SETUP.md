# Configuração do Supabase

1. Crie um projeto no Supabase.
2. No SQL Editor, execute o conteúdo de `supabase-schema.sql`.
3. Em Project Settings > API, copie o Project URL e a chave publicável (`anon` ou `publishable`) para `supabase-config.js`.
4. Publique os arquivos do projeto no GitHub Pages ou em outro host estático.
5. No jogo, informe um apelido e crie uma sala. Compartilhe o código de 8 dígitos; os jogadores entram em dois times automaticamente balanceados.

Não é necessário habilitar login ou criar usuários. As partidas usam canais públicos do Supabase Realtime para mensagens e presença; `guest_matches` guarda salas e `guest_match_players` guarda apelidos e resultados. No multiplayer, os jogadores são divididos automaticamente entre os times azul e vermelho e disputam uma partida PvP até um time chegar a 20 eliminações. O apelido e um identificador aleatório ficam salvos no navegador. O progresso da campanha permanece local neste dispositivo.

Use somente a chave publicável no navegador. Nunca coloque a chave `service_role` no projeto. Como o multiplayer aceita conexões anônimas, nomes, códigos e resultados não são protegidos contra falsificação; é adequado para partidas entre amigos, não para ranking competitivo. A simulação da partida também acontece nos navegadores dos jogadores.

As tabelas antigas de conta (`profiles`, `matches`, `match_players` e `campaign_progress`) foram mantidas no SQL para preservar instalações existentes, mas o jogo não as utiliza no fluxo sem login.