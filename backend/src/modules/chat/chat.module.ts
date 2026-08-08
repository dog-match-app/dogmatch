import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { MatchesModule } from '../matches/matches.module';
import { ChatGateway } from './chat.gateway';

@Module({
  imports: [JwtModule.register({}), MatchesModule],
  providers: [ChatGateway],
})
export class ChatModule {}
