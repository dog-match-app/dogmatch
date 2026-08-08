-- CreateEnum
CREATE TYPE "DogPostType" AS ENUM ('TEXT', 'IMAGE', 'IMAGE_TEXT', 'CAROUSEL');

-- AlterTable
ALTER TABLE "dogs" ADD COLUMN     "social_instagram" TEXT,
ADD COLUMN     "social_pinterest" TEXT,
ADD COLUMN     "social_telegram" TEXT,
ADD COLUMN     "social_whatsapp" TEXT;

-- CreateTable
CREATE TABLE "dog_posts" (
    "id" UUID NOT NULL,
    "dog_id" UUID NOT NULL,
    "type" "DogPostType" NOT NULL,
    "text" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "dog_posts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "dog_post_images" (
    "id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "position" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "dog_post_images_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "dog_post_image_captions" (
    "id" UUID NOT NULL,
    "image_id" UUID NOT NULL,
    "text" TEXT NOT NULL,
    "x" DOUBLE PRECISION NOT NULL,
    "y" DOUBLE PRECISION NOT NULL,

    CONSTRAINT "dog_post_image_captions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "dog_posts_dog_id_created_at_idx" ON "dog_posts"("dog_id", "created_at");

-- CreateIndex
CREATE INDEX "dog_post_images_post_id_idx" ON "dog_post_images"("post_id");

-- CreateIndex
CREATE INDEX "dog_post_image_captions_image_id_idx" ON "dog_post_image_captions"("image_id");

-- AddForeignKey
ALTER TABLE "dog_posts" ADD CONSTRAINT "dog_posts_dog_id_fkey" FOREIGN KEY ("dog_id") REFERENCES "dogs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dog_post_images" ADD CONSTRAINT "dog_post_images_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "dog_posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dog_post_image_captions" ADD CONSTRAINT "dog_post_image_captions_image_id_fkey" FOREIGN KEY ("image_id") REFERENCES "dog_post_images"("id") ON DELETE CASCADE ON UPDATE CASCADE;
