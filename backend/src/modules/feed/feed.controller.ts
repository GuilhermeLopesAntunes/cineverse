import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseIntPipe,
  Post,
  Query,
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { AuthenticatedUser } from '../../common/guards/jwt-auth.guard';
import { CreateReviewDto } from './dto/create-review.dto';
import { ListReviewsQueryDto } from './dto/list-reviews-query.dto';
import {
  FeedService,
  PaginatedReviews,
  ReviewResponse,
  ShareReviewResponse,
} from './feed.service';

@Controller('reviews')
export class FeedController {
  constructor(private readonly feedService: FeedService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateReviewDto,
  ): Promise<ReviewResponse> {
    return this.feedService.create(user.userId, dto);
  }

  @Get()
  list(@Query() query: ListReviewsQueryDto): Promise<PaginatedReviews> {
    return this.feedService.list(query.page, query.pageSize);
  }

  @Get(':id/reveal')
  reveal(@Param('id', ParseIntPipe) id: number): Promise<ReviewResponse> {
    return this.feedService.reveal(id);
  }

  @Get(':id/share')
  share(@Param('id', ParseIntPipe) id: number): Promise<ShareReviewResponse> {
    return this.feedService.share(id);
  }
}
