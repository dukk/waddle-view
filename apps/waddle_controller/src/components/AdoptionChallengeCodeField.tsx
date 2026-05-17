import { TextField, type TextFieldProps } from '@mui/material';
import { formatAdoptionChallengeCodeInput } from '@/util/adoptionChallengeCode';

type Props = Omit<TextFieldProps, 'value' | 'onChange'> & {
  value: string;
  onChange: (value: string) => void;
  /** Called when Enter is pressed (not Shift+Enter). */
  onEnter?: () => void;
};

export function AdoptionChallengeCodeField({
  value,
  onChange,
  onEnter,
  onKeyDown,
  ...rest
}: Props) {
  return (
    <TextField
      {...rest}
      value={value}
      onChange={(e) => onChange(formatAdoptionChallengeCodeInput(e.target.value))}
      onKeyDown={(e) => {
        onKeyDown?.(e);
        if (e.key === 'Enter' && !e.shiftKey && onEnter) {
          e.preventDefault();
          onEnter();
        }
      }}
      inputProps={{
        autoComplete: 'off',
        spellCheck: false,
        style: {
          fontFamily: 'monospace',
          letterSpacing: '0.15em',
          textTransform: 'uppercase',
        },
        ...rest.inputProps,
      }}
    />
  );
}
