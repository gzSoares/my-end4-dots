#!/usr/bin/env bash
set -euo pipefail

SPOT="$HOME/.config/quickshell/ii/modules/spotlight/Spotlight.qml"
BACKUP="$SPOT.bak.$(date +%s)"

if [ ! -f "$SPOT" ]; then
    echo "❌ Spotlight.qml não encontrado em $SPOT"
    exit 1
fi

echo "📦 Backup: $BACKUP"
cp "$SPOT" "$BACKUP"

# Função que insere texto DEPOIS de uma linha que casa com um padrão
insert_after() {
    local pattern="$1"
    local content="$2"
    local desc="$3"

    if grep -qF "$content" "$SPOT"; then
        echo "⏭  $desc (já existe)"
        return 0
    fi

    local line
    line=$(grep -nF "$pattern" "$SPOT" | head -1 | cut -d: -f1 || true)
    if [ -z "$line" ]; then
        echo "⚠️  $desc: âncora não encontrada, pulando"
        return 0
    fi

    python3 - "$SPOT" "$line" "$content" << 'PYEOF'
import sys
path, line_num, content = sys.argv[1], int(sys.argv[2]), sys.argv[3]
with open(path, 'r') as f:
    lines = f.readlines()
lines.insert(line_num, content + "\n")
with open(path, 'w') as f:
    f.writelines(lines)
PYEOF
    echo "✅ $desc"
}

# Função que insere texto ANTES de uma linha
insert_before() {
    local pattern="$1"
    local content="$2"
    local desc="$3"

    if grep -qF "$content" "$SPOT"; then
        echo "⏭  $desc (já existe)"
        return 0
    fi

    local line
    line=$(grep -nF "$pattern" "$SPOT" | head -1 | cut -d: -f1 || true)
    if [ -z "$line" ]; then
        echo "⚠️  $desc: âncora não encontrada, pulando"
        return 0
    fi

    python3 - "$SPOT" "$((line - 1))" "$content" << 'PYEOF'
import sys
path, line_num, content = sys.argv[1], int(sys.argv[2]), sys.argv[3]
with open(path, 'r') as f:
    lines = f.readlines()
lines.insert(line_num, content + "\n")
with open(path, 'w') as f:
    f.writelines(lines)
PYEOF
    echo "✅ $desc"
}

echo ""
echo "═══ Aplicando patches ═══"

# ─── Patch 1: property aiPersistentHistory
insert_after "property bool aiConversationMode: false" \
'    property bool aiPersistentHistory: false' \
"Patch 1: aiPersistentHistory"

# ─── Patch 2: funções de intenção
INTENTS='
    function isScreenshotIntent(p) {
        const s = String(p).toLowerCase();
        return /(o\s+que|analise?|analisa|veja?|olhe?|leia?|traduza?|explica?|explique)\s+(est[áa]|ness[ae]|na|essa?)\s+(tela|screenshot|captura|imagem)/i.test(s)
            || /(o\s+que\s+est[áa]\s+na\s+tela)/i.test(s);
    }

    function isWebSummaryIntent(p) {
        const s = String(p).toLowerCase();
        return /(resuma?|resumir|analise?|analisa|o\s+que\s+diz)\s+(esse\s+)?(link|url|site)/i.test(s)
            || /https?:\/\/\S+/i.test(s) && /(resuma?|analise?|o\s+que)/i.test(s);
    }

    function isPdfSummaryIntent(p) {
        const s = String(p).toLowerCase();
        return /(resuma?|resumir|analise?|analisa)\s+(o\s+|esse\s+|esta\s+)?(pdf|documento)/i.test(s);
    }'

insert_after "function isGitIntent(p) {" \
"$INTENTS" \
"Patch 2: funções de intenção"

echo ""
echo "═══════════════════════════════════════"
echo "  Primeiros patches aplicados"
echo "═══════════════════════════════════════"
echo ""
echo "Os patches 3-10 são mais complexos (envolvem substituição de blocos)."
echo "Backup salvo em: $BACKUP"
echo ""
echo "⚠️  Recomendação: abra o arquivo .spotlight-patches.md e aplique"
echo "   os patches 3-10 MANUALMENTE. Use o backup se algo der errado:"
echo ""
echo "   cp $BACKUP $SPOT"
echo ""
