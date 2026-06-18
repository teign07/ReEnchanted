import {Composition} from 'remotion';
import {ReEnchantedPromo} from './ReEnchantedPromo';

export const RemotionRoot = () => {
  return (
    <Composition
      id="ReEnchantedPromo"
      component={ReEnchantedPromo}
      durationInFrames={1620}
      fps={30}
      width={1080}
      height={1920}
    />
  );
};
