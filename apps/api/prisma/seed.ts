import { prisma } from 'src/lib/prisma';

const DEMO_USER_ID: number = 0;

async function main() {
  await prisma.user.upsert({
    where: { id: DEMO_USER_ID },
    update: {},
    create: {
      id: DEMO_USER_ID,
      email: 'fandreamdev@163.com',
      nickname: 'fandream',
      passwordHash: '<dummy-hash>',
    },
  });
}

main()
  .finally(async () => {
    await prisma.$disconnect();
  })
  .catch((e) => {
    console.error('error', e);
  });
