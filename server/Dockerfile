# Backend Bắc Nam chạy trên Render (hoặc bất kỳ máy nào có Docker).
FROM dart:stable AS build
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY . .
RUN dart pub get --offline && dart compile exe bin/server.dart -o /app/bacnam

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bacnam /app/bacnam
ENV HOST=0.0.0.0
EXPOSE 8080
CMD ["/app/bacnam"]
