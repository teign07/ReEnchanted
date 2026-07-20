import React from 'react';
import {
  AbsoluteFill,
  Easing,
  Img,
  Sequence,
  interpolate,
  random,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import {Audio} from '@remotion/media';

/* ------------------------------------------------------------------ */
/*  Palette + type                                                     */
/* ------------------------------------------------------------------ */

const gold = '#ffc56f';
const goldSoft = '#e8a94e';
const cream = '#f7e8bd';
const ink = '#0a0810';
const teal = '#3aa6ab';
const lavender = '#9a85c9';

const screenshots = {
  home: 'screens/home.png',
  rising: 'screens/rising.png',
  margins: 'screens/margins.png',
  today: 'screens/todays-margins.png',
  weather: 'screens/weather-page.png',
  souvenir: 'screens/souvenir-page.png',
  kept: 'screens/kept-pages.png',
  local: 'screens/local-brain.png',
  glow: 'screens/glow-menu.png',
  cast: 'screens/cast-belief.png',
  spells: 'screens/spells.png',
};

const clamp = {extrapolateLeft: 'clamp' as const, extrapolateRight: 'clamp' as const};
const ease = Easing.bezier(0.16, 1, 0.3, 1);

const serif: React.CSSProperties = {
  fontFamily: '"Iowan Old Style", "Palatino Linotype", Palatino, Georgia, serif',
  fontWeight: 600,
};
const sans: React.CSSProperties = {
  fontFamily:
    'Inter, -apple-system, BlinkMacSystemFont, "SF Pro Display", Helvetica, Arial, sans-serif',
};

/* The real iPhone screen aspect, so screenshots are never awkwardly cropped. */
const SCREEN_RATIO = 2556 / 1179;

/* ------------------------------------------------------------------ */
/*  Scene wrapper — clean cross-dissolve with a breath of scale        */
/* ------------------------------------------------------------------ */

// A one-shot of one of the app's own UI sounds, fired at a given frame.
const Sfx: React.FC<{at: number; file: string; volume?: number}> = ({at, file, volume = 0.5}) => (
  <Sequence from={at} durationInFrames={90} premountFor={15}>
    <Audio src={staticFile(`audio/sfx/${file}.wav`)} volume={volume} />
  </Sequence>
);

const Scene: React.FC<{start: number; end: number; children: React.ReactNode}> = ({
  start,
  end,
  children,
}) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(
    frame,
    [start, start + 22, end - 22, end],
    [0, 1, 1, 0],
    {...clamp, easing: ease},
  );
  const scale = interpolate(frame, [start, end], [1.015, 0.985], clamp);
  return (
    <Sequence from={start} durationInFrames={end - start} premountFor={30}>
      <AbsoluteFill style={{opacity, transform: `scale(${scale})`}}>{children}</AbsoluteFill>
    </Sequence>
  );
};

/* ------------------------------------------------------------------ */
/*  Background — candlelit library: deep ink, soft glow,               */
/*  constellation lines, drifting gold dust                            */
/* ------------------------------------------------------------------ */

const STARS = Array.from({length: 30}).map((_, i) => ({
  x: random(`sx${i}`) * 1080,
  y: random(`sy${i}`) * 1920,
  r: 1.5 + random(`sr${i}`) * 3.5,
  tw: 0.4 + random(`st${i}`) * 0.6,
  spd: 0.5 + random(`sp${i}`) * 1.4,
  teal: random(`sc${i}`) > 0.78,
}));

const LINES: Array<[number, number]> = [
  [0, 1],
  [1, 4],
  [4, 9],
  [9, 13],
  [2, 6],
  [6, 11],
  [3, 8],
  [8, 14],
];

const Background: React.FC = () => {
  const frame = useCurrentFrame();
  const sway = Math.sin(frame / 90) * 1.4;
  return (
    <AbsoluteFill
      style={{
        background:
          'radial-gradient(120% 70% at 50% 30%, rgba(255,197,111,0.10), transparent 55%),' +
          'radial-gradient(90% 60% at 50% 105%, rgba(58,166,171,0.06), transparent 60%),' +
          'linear-gradient(180deg, #06060e 0%, #0e0a16 55%, #060509 100%)',
        overflow: 'hidden',
      }}
    >
      {/* slow constellation field */}
      <AbsoluteFill style={{transform: `rotate(${sway * 0.4}deg)`, opacity: 0.55}}>
        <svg width={1080} height={1920} style={{position: 'absolute'}}>
          {LINES.map(([a, b], i) => (
            <line
              key={i}
              x1={STARS[a].x}
              y1={STARS[a].y}
              x2={STARS[b].x}
              y2={STARS[b].y}
              stroke="rgba(255,197,111,0.14)"
              strokeWidth={1.5}
            />
          ))}
        </svg>
        {STARS.map((s, i) => {
          const twinkle = 0.35 + (Math.sin(frame / (18 / s.spd) + i) * 0.5 + 0.5) * s.tw;
          const c = s.teal ? teal : gold;
          return (
            <div
              key={i}
              style={{
                position: 'absolute',
                left: s.x,
                top: s.y,
                width: s.r * 2,
                height: s.r * 2,
                borderRadius: 999,
                background: c,
                opacity: twinkle,
                boxShadow: `0 0 ${10 + s.r * 4}px ${c}`,
              }}
            />
          );
        })}
      </AbsoluteFill>
      <Dust />
      {/* gentle vignette */}
      <AbsoluteFill
        style={{
          pointerEvents: 'none',
          background: 'radial-gradient(circle at 50% 46%, transparent 50%, rgba(0,0,0,0.55) 100%)',
        }}
      />
    </AbsoluteFill>
  );
};

const Dust: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <>
      {Array.from({length: 36}).map((_, i) => {
        const baseX = random(`dx${i}`) * 1080;
        const baseY = random(`dy${i}`) * 1920;
        const speed = 0.15 + random(`dv${i}`) * 0.35;
        const drift = Math.sin(frame / (40 + i) + i) * 16;
        const y = (baseY - frame * speed) % 2000;
        const size = 2 + random(`ds${i}`) * 4;
        const op = 0.12 + random(`do${i}`) * 0.22;
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: baseX + drift,
              top: y < -20 ? y + 2000 : y,
              width: size,
              height: size,
              borderRadius: 999,
              background: gold,
              opacity: op,
              boxShadow: `0 0 ${8 + size * 3}px rgba(255,197,111,0.6)`,
            }}
          />
        );
      })}
    </>
  );
};

/* ------------------------------------------------------------------ */
/*  Device frame — a real phone: bezel, island, screen, glare          */
/* ------------------------------------------------------------------ */

type PhoneProps = {
  src: string;
  cx: number; // screen-space center x
  cy: number; // screen-space center y
  w: number; // device width
  rotate?: number;
  delay?: number;
  glow?: string;
  z?: number;
  kenburns?: boolean;
  dim?: number; // 0 = full, up to 0.5 to push it back
};

const Phone: React.FC<PhoneProps> = ({
  src,
  cx,
  cy,
  w,
  rotate = 0,
  delay = 0,
  glow = 'rgba(255,197,111,0.30)',
  z = 1,
  kenburns = false,
  dim = 0,
}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const h = w * SCREEN_RATIO;
  const bezel = w * 0.028;
  const radius = w * 0.135;

  const s = spring({frame: frame - delay, fps, config: {damping: 20, stiffness: 90, mass: 0.9}});
  const opacity = interpolate(frame, [delay, delay + 24], [0, 1], {...clamp, easing: ease});
  const rise = interpolate(s, [0, 1], [60, 0]);
  const driftY = Math.sin((frame + delay) / 70) * 6;
  const driftR = Math.sin((frame + delay) / 90) * 0.5;
  const scale = 0.9 + s * 0.1;

  // Ken Burns on the screen content
  const kb = kenburns ? interpolate(frame - delay, [0, 240], [1.0, 1.08], clamp) : 1;
  const kbY = kenburns ? interpolate(frame - delay, [0, 240], [0, -3], clamp) : 0;

  return (
    <div
      style={{
        position: 'absolute',
        left: cx - w / 2,
        top: cy - h / 2 + rise + driftY,
        width: w,
        height: h,
        zIndex: z,
        opacity,
        transform: `rotate(${rotate + driftR}deg) scale(${scale})`,
        filter: dim ? `brightness(${1 - dim})` : undefined,
      }}
    >
      {/* outer body */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          borderRadius: radius,
          background: 'linear-gradient(150deg, #2a2630 0%, #110f16 45%, #07060b 100%)',
          boxShadow: `0 40px 110px rgba(0,0,0,0.6), 0 0 70px ${glow}`,
          border: '1px solid rgba(255,232,180,0.18)',
        }}
      />
      {/* screen */}
      <div
        style={{
          position: 'absolute',
          inset: bezel,
          borderRadius: radius - bezel,
          overflow: 'hidden',
          background: '#05050a',
        }}
      >
        <Img
          src={staticFile(src)}
          style={{
            width: '100%',
            height: '100%',
            objectFit: 'cover',
            objectPosition: 'center top',
            transform: `scale(${kb}) translateY(${kbY}%)`,
            filter: 'saturate(1.05) contrast(1.02)',
          }}
        />
        {/* screen vignette + glare sweep */}
        <div style={{position: 'absolute', inset: 0, boxShadow: 'inset 0 0 60px rgba(0,0,0,0.45)'}} />
        <div
          style={{
            position: 'absolute',
            top: -h,
            left: 0,
            width: '140%',
            height: '120%',
            background:
              'linear-gradient(115deg, transparent 38%, rgba(255,255,255,0.10) 50%, transparent 62%)',
            transform: `translateY(${interpolate((frame + delay) % 300, [0, 300], [0, h * 2.2])}px)`,
          }}
        />
      </div>
    </div>
  );
};

/* ------------------------------------------------------------------ */
/*  Caption — elegant lower third on a parchment panel                 */
/* ------------------------------------------------------------------ */

type CaptionProps = {
  eyebrow?: string;
  title: string;
  body?: string;
  y?: number;
  delay?: number;
  align?: 'left' | 'center';
};

const Caption: React.FC<CaptionProps> = ({
  eyebrow,
  title,
  body,
  y = 1300,
  delay = 0,
  align = 'left',
}) => {
  const frame = useCurrentFrame();
  const p = interpolate(frame, [delay, delay + 26], [0, 1], {...clamp, easing: ease});
  const rule = interpolate(frame, [delay + 6, delay + 40], [0, 1], {...clamp, easing: ease});
  const big = title.length > 34;
  return (
    <div
      style={{
        position: 'absolute',
        left: align === 'center' ? 80 : 88,
        right: align === 'center' ? 80 : undefined,
        width: align === 'center' ? undefined : 904,
        top: y + interpolate(p, [0, 1], [40, 0]),
        opacity: p,
        textAlign: align,
      }}
    >
      {eyebrow ? (
        <div style={{display: 'flex', alignItems: 'center', gap: 18, justifyContent: align === 'center' ? 'center' : 'flex-start', marginBottom: 18}}>
          <div
            style={{
              height: 2,
              width: interpolate(rule, [0, 1], [0, 56]),
              background: gold,
              boxShadow: `0 0 10px ${gold}`,
            }}
          />
          <div
            style={{
              ...sans,
              color: gold,
              fontSize: 28,
              fontWeight: 700,
              letterSpacing: 4,
              textTransform: 'uppercase',
            }}
          >
            {eyebrow}
          </div>
        </div>
      ) : null}
      <div
        style={{
          ...serif,
          color: cream,
          fontSize: big ? 72 : 86,
          lineHeight: 1.02,
          textShadow: '0 6px 40px rgba(0,0,0,0.75)',
        }}
      >
        {title}
      </div>
      {body ? (
        <div
          style={{
            ...sans,
            color: 'rgba(247,232,189,0.82)',
            fontSize: 34,
            lineHeight: 1.3,
            marginTop: 24,
            fontWeight: 500,
            maxWidth: align === 'center' ? 900 : undefined,
            marginLeft: align === 'center' ? 'auto' : undefined,
            marginRight: align === 'center' ? 'auto' : undefined,
          }}
        >
          {body}
        </div>
      ) : null}
    </div>
  );
};

const Pill: React.FC<{children: React.ReactNode; x: number; y: number; delay?: number; color?: string}> = ({
  children,
  x,
  y,
  delay = 0,
  color = gold,
}) => {
  const frame = useCurrentFrame();
  const p = interpolate(frame, [delay, delay + 18], [0, 1], {...clamp, easing: ease});
  return (
    <div
      style={{
        ...sans,
        position: 'absolute',
        left: x,
        top: y + interpolate(p, [0, 1], [18, 0]),
        padding: '16px 30px',
        borderRadius: 999,
        border: `1.5px solid ${color}`,
        background: 'rgba(10,8,16,0.6)',
        backdropFilter: 'blur(6px)',
        color: cream,
        fontSize: 29,
        fontWeight: 700,
        letterSpacing: 1,
        opacity: p,
        boxShadow: `0 0 26px ${color}44`,
      }}
    >
      {children}
    </div>
  );
};

/* ------------------------------------------------------------------ */
/*  Scenes                                                             */
/* ------------------------------------------------------------------ */

// Opens on the ache: routine, the grey, Routine — before the Book answers it.
const SceneHook: React.FC = () => {
  const frame = useCurrentFrame();
  const eyeP = interpolate(frame, [8, 40], [0, 1], {...clamp, easing: ease});
  const lineP = interpolate(frame, [22, 64], [0, 1], {...clamp, easing: ease});
  return (
    <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', padding: '0 90px'}}>
      <div style={{textAlign: 'center'}}>
        <div
          style={{
            ...sans,
            color: gold,
            fontSize: 30,
            fontWeight: 700,
            letterSpacing: 6,
            textTransform: 'uppercase',
            opacity: eyeP,
            transform: `translateY(${interpolate(eyeP, [0, 1], [20, 0])}px)`,
          }}
        >
          Boredom. Routine. The grey.
        </div>
        <div
          style={{
            ...serif,
            color: cream,
            fontSize: 88,
            lineHeight: 1.08,
            marginTop: 34,
            textShadow: '0 6px 40px rgba(0,0,0,0.7)',
            opacity: lineP,
            transform: `translateY(${interpolate(lineP, [0, 1], [40, 0])}px)`,
          }}
        >
          Life slips past, unread —<br />and Routine creeps in.
        </div>
      </div>
    </AbsoluteFill>
  );
};

const SceneOpen: React.FC = () => {
  const frame = useCurrentFrame();
  const titleP = interpolate(frame, [10, 46], [0, 1], {...clamp, easing: ease});
  const subP = interpolate(frame, [30, 70], [0, 1], {...clamp, easing: ease});
  return (
    <>
      <Phone src={screenshots.home} cx={540} cy={720} w={540} delay={6} kenburns glow="rgba(255,197,111,0.40)" />
      <div
        style={{
          position: 'absolute',
          left: 80,
          right: 80,
          top: 1290,
          textAlign: 'center',
          opacity: titleP,
          transform: `translateY(${interpolate(titleP, [0, 1], [40, 0])}px)`,
        }}
      >
        <div style={{...sans, color: gold, fontSize: 30, fontWeight: 700, letterSpacing: 6, textTransform: 'uppercase'}}>
          ReEnchanted
        </div>
        <div style={{...serif, color: cream, fontSize: 88, lineHeight: 1.02, marginTop: 20, textShadow: '0 6px 40px rgba(0,0,0,0.7)'}}>
          Real Life,<br />
          <span style={{color: gold}}>ReEnchanted</span>
        </div>
      </div>
      <div
        style={{
          position: 'absolute',
          left: 80,
          right: 80,
          top: 1560,
          textAlign: 'center',
          opacity: subP,
          transform: `translateY(${interpolate(subP, [0, 1], [30, 0])}px)`,
        }}
      >
        <div style={{...sans, color: 'rgba(247,232,189,0.85)', fontSize: 33, lineHeight: 1.3, fontWeight: 500}}>
          A free, magical iPhone book that turns the day<br />you actually lived into a faerie tale.
        </div>
        <div style={{...serif, color: gold, fontSize: 32, marginTop: 18, fontStyle: 'italic'}}>
          The old kind. The sometimes dangerous kind.
        </div>
      </div>
    </>
  );
};

const SceneNotice: React.FC = () => (
  <>
    <Phone src={screenshots.today} cx={420} cy={640} w={500} rotate={-4} delay={0} z={2} glow="rgba(58,166,171,0.4)" />
    <Phone src={screenshots.rising} cx={760} cy={760} w={430} rotate={5} delay={16} z={1} dim={0.18} glow="rgba(255,197,111,0.3)" />
    <Caption
      eyebrow="Pages rise"
      title="The Book notices what the day almost let slip."
      body="Weather, body, places, moods — small true things, surfaced when they matter."
      y={1320}
      delay={28}
    />
  </>
);

const SceneKeep: React.FC = () => (
  <>
    <Phone src={screenshots.souvenir} cx={400} cy={580} w={430} rotate={-5} delay={0} z={2} glow="rgba(255,197,111,0.36)" />
    <Phone src={screenshots.kept} cx={730} cy={720} w={430} rotate={4} delay={16} z={1} dim={0.2} glow="rgba(154,133,201,0.32)" />
    <Caption
      eyebrow="Keep what matters"
      title="A walk. A sentence. A page worth coming back to."
      body="Keep the moments that count, and the Book remembers them for you."
      y={1320}
      delay={30}
    />
  </>
);

const ScenePrivate: React.FC = () => (
  <>
    <Phone src={screenshots.local} cx={540} cy={700} w={560} delay={4} kenburns glow="rgba(58,166,171,0.45)" />
    <Caption
      eyebrow="Local brain"
      title="Private by design."
      body="Gemma runs on-device. No account, no cloud — it still works in airplane mode."
      y={1300}
      delay={22}
    />
    <Pill x={90} y={1640} delay={50}>Free</Pill>
    <Pill x={272} y={1640} delay={60} color={teal}>Local</Pill>
    <Pill x={488} y={1640} delay={70} color={lavender}>Private</Pill>
    <Pill x={742} y={1640} delay={80} color={goldSoft}>Offline</Pill>
  </>
);

const SceneGlow: React.FC = () => (
  <>
    <Phone src={screenshots.glow} cx={400} cy={640} w={470} rotate={-4} delay={0} z={2} glow="rgba(255,197,111,0.34)" />
    <Phone src={screenshots.cast} cx={740} cy={760} w={430} rotate={4} delay={16} z={1} dim={0.2} glow="rgba(58,166,171,0.32)" />
    <Caption
      eyebrow="Glow"
      title="Attention becomes a force."
      body="Give Belief to the people, pages, and parts of the world you want to hear from again."
      y={1330}
      delay={30}
    />
  </>
);

const ScenePlay: React.FC = () => (
  <>
    <Phone src={screenshots.spells} cx={730} cy={600} w={450} rotate={4} delay={0} z={2} glow="rgba(255,197,111,0.32)" />
    <Phone src={screenshots.margins} cx={380} cy={780} w={450} rotate={-4} delay={16} z={1} dim={0.2} glow="rgba(154,133,201,0.34)" />
    <Caption
      eyebrow="Play"
      title="Compass runs. Enchantments. Letters. Stories."
      body="Use the camera like a wand. Let the cast write to you. Make ordinary moments into missions."
      y={1330}
      delay={30}
    />
  </>
);

const SceneClose: React.FC = () => {
  const frame = useCurrentFrame();
  const p = interpolate(frame, [16, 50], [0, 1], {...clamp, easing: ease});
  return (
    <>
      <Phone src={screenshots.home} cx={540} cy={660} w={500} delay={4} kenburns glow="rgba(255,197,111,0.5)" />
      <div
        style={{
          position: 'absolute',
          left: 80,
          right: 80,
          top: 1240,
          textAlign: 'center',
          opacity: p,
          transform: `translateY(${interpolate(p, [0, 1], [40, 0])}px)`,
        }}
      >
        <div style={{...serif, color: cream, fontSize: 84, lineHeight: 1.04, textShadow: '0 6px 40px rgba(0,0,0,0.7)'}}>
          Play with pages.<br />Keep some.<br />Read your story.
        </div>
        <div style={{...sans, color: gold, fontSize: 36, marginTop: 30, fontWeight: 600, fontStyle: 'italic'}}>
          The Book is listening.
        </div>
      </div>
      <div
        style={{
          ...sans,
          position: 'absolute',
          left: 0,
          right: 0,
          bottom: 120,
          textAlign: 'center',
          color: 'rgba(247,232,189,0.66)',
          fontSize: 28,
          fontWeight: 700,
          letterSpacing: 3,
          opacity: interpolate(frame, [40, 70], [0, 1], clamp),
        }}
      >
        FREE · PRIVATE · LOCAL · OPEN SOURCE
      </div>
    </>
  );
};

/* ------------------------------------------------------------------ */
/*  Timeline — tighter, ~48s                                           */
/* ------------------------------------------------------------------ */

const SceneTimeline: React.FC = () => (
  <>
    <Scene start={0} end={210}>
      <SceneHook />
    </Scene>
    <Scene start={190} end={425}>
      <SceneOpen />
    </Scene>
    <Scene start={405} end={655}>
      <SceneNotice />
    </Scene>
    <Scene start={635} end={885}>
      <SceneKeep />
    </Scene>
    <Scene start={865} end={1120}>
      <ScenePrivate />
    </Scene>
    <Scene start={1100} end={1345}>
      <SceneGlow />
    </Scene>
    <Scene start={1325} end={1580}>
      <ScenePlay />
    </Scene>
    <Scene start={1560} end={1810}>
      <SceneClose />
    </Scene>
  </>
);

export const ReEnchantedPromo: React.FC = () => {
  const frame = useCurrentFrame();
  const fadeIn = interpolate(frame, [0, 30], [1, 0], clamp);
  const outDim = interpolate(frame, [1750, 1810], [0, 0.4], clamp);
  return (
    <AbsoluteFill style={{backgroundColor: ink}}>
      <Background />
      {/* Musical bed: "Mossy Footsteps" — see RemotionPromo/CREDITS.md. */}
      <Audio
        src={staticFile('audio/mossy-footsteps.mp3')}
        volume={(f) => interpolate(f, [0, 30, 1690, 1810], [0, 0.78, 0.78, 0], clamp)}
      />
      {/* The app's own sounds, punctuating each beat. */}
      <Sfx at={22} file="source-refresh" volume={0.32} />
      <Sfx at={198} file="open-page" volume={0.5} />
      <Sfx at={412} file="source-refresh" volume={0.42} />
      <Sfx at={660} file="keep-page" volume={0.55} />
      <Sfx at={880} file="select" volume={0.5} />
      <Sfx at={1130} file="source-refresh" volume={0.4} />
      <Sfx at={1345} file="tap" volume={0.5} />
      <Sfx at={1578} file="braid-start" volume={0.45} />
      <Sfx at={1620} file="braid-complete" volume={0.5} />
      <SceneTimeline />
      {/* opening fade-from-black */}
      <AbsoluteFill style={{pointerEvents: 'none', backgroundColor: `rgba(0,0,0,${fadeIn})`}} />
      {/* closing settle */}
      <AbsoluteFill style={{pointerEvents: 'none', backgroundColor: `rgba(0,0,0,${outDim})`}} />
    </AbsoluteFill>
  );
};
