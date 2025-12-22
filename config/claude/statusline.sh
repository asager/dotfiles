#!/bin/bash
# Claude Code status line - worktree, temperature, and Tolkien wisdom

input=$(cat)
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir // empty')

# Determine worktree name
CANONICAL="/Users/andrewsager/Documents/Aeglos/Technical"

if [[ -z "$CURRENT_DIR" ]]; then
    WORKTREE="unknown"
elif [[ "$CURRENT_DIR" == "$CANONICAL"* ]]; then
    WORKTREE="Aeglos main"
elif [[ "$CURRENT_DIR" =~ /Documents/Aeglos/wkt-([^/]+) ]]; then
    WORKTREE="${BASH_REMATCH[1]}"
elif [[ "$CURRENT_DIR" == "/" ]]; then
    WORKTREE="/"
else
    WORKTREE="${CURRENT_DIR##*/}"
    # Handle trailing slash edge case
    [[ -z "$WORKTREE" ]] && WORKTREE="${CURRENT_DIR%/}" && WORKTREE="${WORKTREE##*/}"
    [[ -z "$WORKTREE" ]] && WORKTREE="unknown"
fi

# Temperature caching (refresh every 10 minutes)
CACHE_FILE="/tmp/claude_weather_cache"
CACHE_MAX_AGE=600

get_temperature() {
    curl -s --max-time 2 "wttr.in/West+Village,NYC?format=%t" 2>/dev/null | tr -d '+'
}

TEMP=""
if [[ -f "$CACHE_FILE" ]]; then
    CACHE_AGE=$(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)))
    if [[ $CACHE_AGE -lt $CACHE_MAX_AGE ]]; then
        TEMP=$(cat "$CACHE_FILE")
    fi
fi

if [[ -z "$TEMP" ]]; then
    TEMP=$(get_temperature)
    if [[ -n "$TEMP" && "$TEMP" != *"Unknown"* ]]; then
        echo "$TEMP" > "$CACHE_FILE"
    else
        TEMP="--"
    fi
fi

# Tolkien quotes - lesser-known wisdom (rotate hourly)
# Sources: LOTR, Silmarillion, Hobbit, Letters of J.R.R. Tolkien
QUOTES=(
    # On Wisdom and Judgment
    "He that breaks a thing to find out what it is has left the path of wisdom."
    "The treacherous are ever distrustful."
    "The burned hand teaches best."
    "Pay heed to the tales of old wives. It may well be that they alone keep what the wise once knew."
    "To him that is pitiless the deeds of pity are ever strange and beyond reckoning."
    "The most improper job of any man is bossing other men. Not one in a million is fit for it."
    "Do not scorn pity that is the gift of a gentle heart."
    "It is perilous to study too deeply the arts of the Enemy, for good or for ill."

    # On Work and Perseverance
    "It is the job that is never started as takes longest to finish."
    "Little by little, one travels far."
    "Deeds will not be less valiant because they are unpraised."
    "Short cuts make long delays."
    "Someone else always has to carry on the story."
    "Such is oft the course of deeds that move the wheels of the world: small hands do them because they must."
    "Keep up your hobbitry in heart, and think that all stories feel like that when you are in them."

    # On Hope and Despair
    "It is not despair, for despair is only for those who see the end beyond all doubt."
    "Faithless is he that says farewell when the road darkens."
    "Where there is life there is hope, and need of vittles."
    "Aurë entuluva! Day shall come again!"
    "Evil labours with vast power and perpetual success—in vain: preparing only soil for unexpected good."
    "His grief he will not forget; but it will not darken his heart, it will teach him wisdom."
    "Help oft shall come from the hands of the weak when the Wise falter."

    # On Purpose and Meaning
    "I want to be a healer, and love all things that grow and are not barren."
    "All have their worth and each contributes to the worth of the others."
    "The love of Arda was set in your hearts by Ilúvatar, and he does not plant to no purpose."
    "One who cannot cast away a treasure at need is in fetters."
    "If more of us valued food and cheer and song above hoarded gold, it would be a merrier world."

    # On Defending What Matters
    "I do not love the bright sword for its sharpness. I love only that which they defend."
    "It is not our part to master all the tides of the world, but to do what is in us for the succour of those years wherein we are set."
    "Uprooting the evil in the fields that we know, so that those who live after may have clean earth to till."

    # On Human Nature
    "A hunted man sometimes wearies of distrust and longs for friendship."
    "Men's hearts are not often as bad as their acts, and very seldom as bad as their words."
    "We all long for Eden, and we are constantly glimpsing it."
    "The greater part of the truth is always hidden, in regions out of the reach of cynicism."
    "A traitor may betray himself and do good that he does not intend."

    # On Learning and Growth
    "A good vocabulary comes from reading books above one."
    "Life is rather above the measure of us all. We need literature that is above our measure."
    "I did not desire such lordship. I desired things other than I am, to love and to teach them."

    # On Joy and Sorrow
    "I will not say: do not weep; for not all tears are an evil."
    "If joyful is the fountain that rises in the sun, its springs are in the wells of sorrow."
    "In all lands love is now mingled with grief, it grows perhaps the greater."

    # On Art and Creation
    "The object is Art not power, sub-creation not domination."
    "Legends and myths are largely made of truth, presenting aspects that can only be received in this mode."
    "Love not too well the work of thy hands and the devices of thy heart."

    # Practical Wisdom
    "It does not do to leave a live dragon out of your calculations, if you live near one."
    "He longed to shut out the immensity in a quiet room by a fire."
    "May your beer be laid under an enchantment of surpassing excellence."
    "This is a bitter adventure, if it must end so; and not a mountain of gold can amend it."

    # On Courage
    "Courage is found in unlikely places."
    "The world is indeed full of peril, and in it there are many dark places; but still there is much that is fair."

    # Understated Wit
    "I was talking aloud to myself. A habit of the old: they choose the wisest person present to speak to."
    "Good things that are good to have and days that are good to spend are soon told about, and not much to listen to."
    "That we should try to destroy the Ring itself has not yet entered into his darkest dream."
)

QUOTE_CACHE="/tmp/claude_lotr_quote"
QUOTE_MAX_AGE=3600  # 1 hour

QUOTE=""
if [[ -f "$QUOTE_CACHE" ]]; then
    QUOTE_AGE=$(($(date +%s) - $(stat -f %m "$QUOTE_CACHE" 2>/dev/null || echo 0)))
    if [[ $QUOTE_AGE -lt $QUOTE_MAX_AGE ]]; then
        QUOTE=$(cat "$QUOTE_CACHE")
    fi
fi

if [[ -z "$QUOTE" ]]; then
    QUOTE="${QUOTES[$((RANDOM % ${#QUOTES[@]}))]}"
    echo "$QUOTE" > "$QUOTE_CACHE"
fi

echo "$WORKTREE | $TEMP | $QUOTE"
