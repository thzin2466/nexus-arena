# Configuração do Supabase

1. Crie um projeto no Supabase.
2. Abra o SQL Editor e execute o conteúdo de `supabase-schema.sql`.
3. Em Project Settings > API, copie o Project URL e a chave publicável (anon) para `supabase-config.js`.
4. Em Authentication > URL Configuration, configure a URL do GitHub Pages como Site URL e Redirect URL.
5. Em Authentication > Providers, habilite Email. Se a confirmação de e-mail estiver ativa, confirme o cadastro antes de entrar.
6. Publique os arquivos do repositório no GitHub Pages.

Use somente a chave publicável no navegador. Nunca coloque `service_role` em `supabase-config.js` nem no GitHub.

## Dados guardados

- `profiles`: apelido associado à conta autenticada.
- `matches` e `match_players`: salas e resultados por jogador.
- `campaign_progress`: fase e eliminações da campanha.
- `leaderboard`: visão agregada de partidas, eliminações e vitórias.

Sem URL e chave configuradas, o jogo continua disponível offline; login, ranking e persistência online ficam desativados. As partidas ao vivo usam PeerJS. Como a simulação e o envio de resultados acontecem no navegador, esse ranking é adequado para amigos/demonstração, não para competição com proteção contra trapaças. Para isso seria necessário um servidor de jogo autoritativo.
