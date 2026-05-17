import { TextField, type TextFieldProps } from '@mui/material';
import { formatAdoptionChallengeCodeInput } from '@/util/adoptionChallengeCode';

type Props = Omit<TextFieldProps, 'value' | 'onChange'> & {
  value: string;
  onChange: (value: string) => void;
};

export function AdoptionChallengeCodeField({ value, onChange, ...rest }: Props) {
  return (
    <TextField
      {...rest}
      value={value}
      onChange={(e) => onChange(formatAdoptionChallengeCodeInput(e.target.value))}
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
