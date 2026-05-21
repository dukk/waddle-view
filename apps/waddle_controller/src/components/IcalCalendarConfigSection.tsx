import { useCallback, useMemo, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  IconButton,
  Link,
  List,
  ListItem,
  ListItemText,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import {
  ContentCategorySelect,
  type ContentCategoryOption,
} from '@/components/config/ContentCategorySelectField';
import {
  isValidIcalFeedUrl,
  mergeFeedIntoList,
  newIcalFeedId,
  type IcalCalendarConfigState,
  type IcalFeedConfig,
} from '@/util/icalCalendarConfig';
import {
  feedFromSuggestion,
  feedListHasUrl,
  ICAL_SUGGESTED_WEBCAL_GURU_FEEDS,
  kWebcalGuruSignupMessage,
  kWebcalGuruSignupUrl,
  type IcalSuggestedFeed,
} from '@/util/icalSuggestedFeeds';

export type { ContentCategoryOption };

type Props = {
  value: IcalCalendarConfigState;
  onChange: (next: IcalCalendarConfigState) => void;
  categories: ContentCategoryOption[];
  disabled?: boolean;
};

export function IcalCalendarConfigSection({
  value,
  onChange,
  categories,
  disabled = false,
}: Props) {
  const [urlDraft, setUrlDraft] = useState('');
  const [urlError, setUrlError] = useState<string | null>(null);
  const [suggestedError, setSuggestedError] = useState<string | null>(null);

  const defaultCategoryId = useMemo(
    () => categories[0]?.id ?? '',
    [categories],
  );

  const addFeed = useCallback(() => {
    const url = urlDraft.trim();
    if (!url) {
      setUrlError('Enter a feed URL.');
      return;
    }
    if (!isValidIcalFeedUrl(url)) {
      setUrlError('URL must start with http://, https://, or webcal://');
      return;
    }
    if (!defaultCategoryId) {
      setUrlError('Add content categories on the display before adding feeds.');
      return;
    }
    const feed: IcalFeedConfig = {
      id: newIcalFeedId(),
      url,
      categoryId: defaultCategoryId,
    };
    onChange({
      ...value,
      feeds: mergeFeedIntoList(value.feeds, feed),
    });
    setUrlDraft('');
    setUrlError(null);
  }, [defaultCategoryId, onChange, urlDraft, value]);

  const patchFeed = (id: string, partial: Partial<IcalFeedConfig>) => {
    onChange({
      ...value,
      feeds: value.feeds.map((f) => (f.id === id ? { ...f, ...partial } : f)),
    });
  };

  const removeFeed = (id: string) => {
    onChange({
      ...value,
      feeds: value.feeds.filter((f) => f.id !== id),
    });
  };

  const addSuggestedFeed = useCallback(
    (suggestion: IcalSuggestedFeed) => {
      if (!defaultCategoryId) {
        setSuggestedError('Add content categories on the display before adding feeds.');
        return;
      }
      if (feedListHasUrl(value.feeds, suggestion.url)) {
        setSuggestedError(`${suggestion.label} is already in your feed list.`);
        return;
      }
      const feed = feedFromSuggestion(suggestion, defaultCategoryId);
      onChange({
        ...value,
        feeds: mergeFeedIntoList(value.feeds, feed),
      });
      setSuggestedError(null);
    },
    [defaultCategoryId, onChange, value],
  );

  const canAddFeeds = !disabled && categories.length > 0;

  return (
    <Stack spacing={2}>
      <Typography variant="subtitle2">iCal / ICS feeds</Typography>

      <Alert severity="info">
        {kWebcalGuruSignupMessage}{' '}
        <Link href={kWebcalGuruSignupUrl} target="_blank" rel="noopener noreferrer">
          Sign up at WebCal.Guru
        </Link>
      </Alert>

      <Typography variant="subtitle2">Suggested calendars (WebCal.Guru)</Typography>
      {suggestedError ? (
        <Alert severity="warning" onClose={() => setSuggestedError(null)}>
          {suggestedError}
        </Alert>
      ) : null}
      <List dense disablePadding sx={{ border: 1, borderColor: 'divider', borderRadius: 1 }}>
        {ICAL_SUGGESTED_WEBCAL_GURU_FEEDS.map((suggestion) => {
          const alreadyAdded = feedListHasUrl(value.feeds, suggestion.url);
          return (
            <ListItem
              key={suggestion.url}
              secondaryAction={
                <Button
                  size="small"
                  variant="outlined"
                  onClick={() => addSuggestedFeed(suggestion)}
                  disabled={!canAddFeeds || alreadyAdded}
                >
                  {alreadyAdded ? 'Added' : 'Add'}
                </Button>
              }
              sx={{ pr: 10 }}
            >
              <ListItemText
                primary={suggestion.label}
                secondary={suggestion.url}
                secondaryTypographyProps={{ noWrap: true, title: suggestion.url }}
              />
            </ListItem>
          );
        })}
      </List>

      {categories.length === 0 ? (
        <Alert severity="info">
          No content categories are available yet. Seed or add categories on the display, then
          return to assign a category per feed.
        </Alert>
      ) : null}

      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} alignItems="flex-start">
        <TextField
          label="Feed URL"
          placeholder="https://calendar.example.com/public/feed.ics"
          value={urlDraft}
          onChange={(e) => {
            setUrlDraft(e.target.value);
            if (urlError) setUrlError(null);
          }}
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              e.preventDefault();
              addFeed();
            }
          }}
          disabled={disabled || categories.length === 0}
          size="small"
          fullWidth
          error={urlError != null}
          helperText={urlError ?? 'http(s) or webcal:// ICS subscription URL'}
        />
        <Button
          variant="outlined"
          onClick={addFeed}
          disabled={disabled || categories.length === 0}
          sx={{ flexShrink: 0, mt: { xs: 0, sm: 0.25 } }}
        >
          Add feed
        </Button>
      </Stack>

      <Typography variant="subtitle2">Configured feeds</Typography>
      {value.feeds.length === 0 ? (
        <Alert severity="info">Add at least one feed with a category before enabling.</Alert>
      ) : (
        value.feeds.map((feed) => (
          <Stack
            key={feed.id}
            spacing={1.5}
            sx={{ p: 1.5, border: 1, borderColor: 'divider', borderRadius: 1 }}
          >
            <Stack direction="row" alignItems="flex-start" justifyContent="space-between">
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="body2" fontWeight={600} noWrap title={feed.url}>
                  {feed.label ?? feed.url}
                </Typography>
                {feed.label ? (
                  <Typography variant="caption" color="text.secondary" noWrap title={feed.url}>
                    {feed.url}
                  </Typography>
                ) : null}
              </Box>
              <IconButton
                aria-label="Remove feed"
                onClick={() => removeFeed(feed.id)}
                disabled={disabled}
                size="small"
              >
                <DeleteOutlineIcon fontSize="small" />
              </IconButton>
            </Stack>
            <TextField
              label="Feed URL"
              value={feed.url}
              onChange={(e) => patchFeed(feed.id, { url: e.target.value })}
              disabled={disabled}
              size="small"
              fullWidth
            />
            <TextField
              label="Label (optional)"
              value={feed.label ?? ''}
              onChange={(e) => {
                const next = e.target.value.trim();
                patchFeed(feed.id, { label: next === '' ? undefined : next });
              }}
              disabled={disabled}
              size="small"
              fullWidth
            />
            <ContentCategorySelect
              id={`ical-feed-cat-${feed.id}`}
              label="Category"
              value={feed.categoryId}
              onChange={(categoryId) => patchFeed(feed.id, { categoryId })}
              categories={categories}
              disabled={disabled}
            />
          </Stack>
        ))
      )}
    </Stack>
  );
}
