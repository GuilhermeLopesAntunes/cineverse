import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { db } from '../../prisma/db';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import {
  accessTokenConfig,
  refreshTokenConfig,
} from '../../common/config/jwt.config';
import { isUniqueViolation } from '../../common/prisma/is-unique-violation';

const BCRYPT_SALT_ROUNDS = 10;
// Compared against when the e-mail doesn't exist, so a login attempt takes
// roughly the same time whether or not the account is real — otherwise
// response timing alone would let an attacker enumerate registered e-mails.
const DUMMY_PASSWORD_HASH = bcrypt.hashSync(
  'not-a-real-password',
  BCRYPT_SALT_ROUNDS,
);

export interface PublicUser {
  id: number;
  email: string;
  name: string | null;
  createdAt: string;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

@Injectable()
export class AuthService {
  constructor(private readonly jwtService: JwtService) {}

  async login(dto: LoginDto): Promise<AuthTokens> {
    const user = await db.orm.public.User.where({ email: dto.email })
      .select('id', 'email', 'passwordHash')
      .first();

    const passwordMatches = await bcrypt.compare(
      dto.password,
      user?.passwordHash ?? DUMMY_PASSWORD_HASH,
    );
    if (!user || !passwordMatches) {
      throw new UnauthorizedException('Credenciais inválidas');
    }

    return this.issueTokens(user.id, user.email);
  }

  async register(dto: RegisterDto): Promise<PublicUser> {
    const passwordHash = await bcrypt.hash(dto.password, BCRYPT_SALT_ROUNDS);

    try {
      return await db.orm.public.User.select(
        'id',
        'email',
        'name',
        'createdAt',
      ).create({
        email: dto.email,
        name: dto.name,
        passwordHash,
      });
    } catch (err) {
      if (isUniqueViolation(err)) {
        throw new ConflictException('E-mail já cadastrado');
      }
      throw err;
    }
  }

  private async issueTokens(
    userId: number,
    email: string,
  ): Promise<AuthTokens> {
    const [accessToken, refreshToken] = await Promise.all([
      this.jwtService.signAsync(
        { sub: userId, email },
        {
          secret: accessTokenConfig.secret,
          expiresIn: accessTokenConfig.expiresIn,
        },
      ),
      this.jwtService.signAsync(
        { sub: userId },
        {
          secret: refreshTokenConfig.secret,
          expiresIn: refreshTokenConfig.expiresIn,
        },
      ),
    ]);
    return { accessToken, refreshToken };
  }
}
