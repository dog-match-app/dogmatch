import { MatchDto } from '../../modules/matches/dto/match.dto';
import { MessageDto } from '../../modules/matches/dto/message.dto';

export const MATCH_CREATED_EVENT = 'match.created';
export const MESSAGE_CREATED_EVENT = 'message.created';

export interface MatchCreatedEvent {
  matchId: string;
  recipients: {
    userId: string;
    match: MatchDto;
  }[];
}

export interface MessageCreatedEvent {
  matchId: string;
  senderUserId: string;
  recipientUserId: string;
  message: MessageDto;
}
