import '../models/test_model.dart';

class TestData {
  static final List<MentalTest> allTests = [
    MentalTest(
      id: 'iq_testi',
      title: 'IQ Testi (Bilişsel Yetenek)',
      description: 'Mantıksal çıkarım ve desen tanıma yeteneğini ölçer.',
      analysisPrompt: 'Kullanıcının 5 soruluk kısa IQ/Mantık testinden aldığı ham puan: {score} (Maksimum 50). Bu puanı standard IQ puanı olarak DEĞİL, zihinsel kıvraklık, mantık yürütme ve dikkat potansiyeli olarak yorumla. 50/50 tam puan alan bir kullanıcıyı "Üstün Mantıksal Zeka" olarak onurlandır ve tavsiyelerde bulun.',
      questions: [
        TestQuestion(
          id: 'q1',
          text: '2, 4, 8, 16... dizisindeki bir sonraki sayı nedir?',
          options: [
            TestOption(text: '24', value: 0),
            TestOption(text: '32', value: 10),
            TestOption(text: '64', value: 0),
          ],
        ),
        TestQuestion(
          id: 'q2',
          text: 'Eğer tüm güller çiçek ise ve bazı çiçekler soluyorsa, tüm güller solar mı?',
          options: [
            TestOption(text: 'Evet, solar', value: 0),
            TestOption(text: 'Hayır, kesin değil', value: 10),
            TestOption(text: 'Güller asla solmaz', value: 0),
          ],
        ),
        TestQuestion(
          id: 'q3',
          text: 'Tereddüt kelimesinin zıt anlamlısı nedir?',
          options: [
            TestOption(text: 'Şüphe', value: 0),
            TestOption(text: 'Kararlılık', value: 10),
            TestOption(text: 'Endişe', value: 0),
          ],
        ),
        TestQuestion(
          id: 'q4',
          text: 'Terzi için "İğne" neyse, Ressam için .... odur.',
          options: [
            TestOption(text: 'Boyun', value: 0),
            TestOption(text: 'Fırça', value: 10),
            TestOption(text: 'Tablo', value: 0),
          ],
        ),
        TestQuestion(
          id: 'q5',
          text: 'Bir bakkal 3 boş şişeye 1 dolu şişe bedava veriyor. 9 boş şişesi olan biri en fazla kaç dolu şişe alabilir?',
          options: [
            TestOption(text: '3', value: 5),
            TestOption(text: '4', value: 10),
            TestOption(text: '5', value: 0),
          ],
        ),
      ],
    ),
    MentalTest(
      id: 'eq_testi',
      title: 'EQ Testi (Duygusal Zeka)',
      description: 'Duyguları anlama, yönetme ve empati kurma becerisini ölçer.',
      analysisPrompt: 'Uzman bir Duygusal Zeka (EQ) koçu gibi davran. Kullanıcıya klişe tavsiyeler yerine, verdiği spesifik cevaplardaki (tepki hızı, empati yaklaşımı) nüansları fark ederek dürüst bir feedback ver. {score} puanının ötesine geç.',
      questions: [
        TestQuestion(
          id: 'e1',
          text: 'Bir arkadaşınız çok üzgün olduğunda ve hıçkırarak ağladığında ilk iç güdünüz nedir?',
          options: [
            TestOption(text: 'Sessizce yanına oturur, elini tutar veya sarılırım (Fiziksel/Sessiz destek)', value: 10),
            TestOption(text: '"Sorun değil, geçecek" diyerek rasyonel çözümler sunarım', value: 5),
            TestOption(text: 'Konuyu dağıtacak bir espri yapar veya dışarı çıkmayı teklif ederim', value: 2),
            TestOption(text: 'Ona ne yapması gerektiğini madde madde anlatırım', value: 3),
          ],
        ),
        TestQuestion(
          id: 'e2',
          text: 'Bir tartışma sırasında haksız olduğunuzu o an fark ederseniz tepkiniz ne olur?',
          options: [
            TestOption(text: 'Hemen durur, hatamı kabul eder ve özür dilerim', value: 10),
            TestOption(text: 'Konuyu bir şekilde kendi haklılığıma bağlamaya çalışırım', value: 3),
            TestOption(text: 'Tartışmayı sessizce terk ederim', value: 5),
            TestOption(text: 'Kabul ederim ama karşı tarafın da hatalarını hemen hatırlatırım', value: 7),
          ],
        ),
      ],
    ),
    MentalTest(
      id: 'travma_analizi',
      title: 'Travma Analizi (Yaşam Ölçeği)',
      description: 'Geçmiş deneyimlerin bugünkü ruh hali üzerindeki etkileri.',
      analysisPrompt: 'Kullanıcının travma ölçeği puanı {score}. Bu skoru hassasiyet ve iyileşme odaklı yorumla.',
      questions: [
        TestQuestion(
          id: 't1',
          text: 'Geçmişte yaşanan olumsuz olayları sık sık hatırlar mısınız?',
          options: [
            TestOption(text: 'Hiçbir zaman', value: 0),
            TestOption(text: 'Bazen', value: 5),
            TestOption(text: 'Sık sık', value: 10),
          ],
        ),
        TestQuestion(
          id: 't2',
          text: 'İnsanlara güvenmekte zorluk çeker misiniz?',
          options: [
            TestOption(text: 'Hayır, kolay güvenirim', value: 0),
            TestOption(text: 'Biraz zaman alabilir', value: 5),
            TestOption(text: 'Evet, çok zordur', value: 10),
          ],
        ),
        TestQuestion(
          id: 't3',
          text: 'Geleceğe dair umudunuzu ne sıklıkla kaybedersiniz?',
          options: [
            TestOption(text: 'Nadiren', value: 0),
            TestOption(text: 'Zaman zaman', value: 5),
            TestOption(text: 'Sık sık', value: 10),
          ],
        ),
      ],
    ),
    MentalTest(
      id: 'mbti_kisilik',
      title: 'Kişilik Analizi (Hızlı MBTI)',
      description: 'Dışa dönük mü yoksa içe dönük mü olduğunuzu ve karar verme tarzınızı belirler.',
      analysisPrompt: 'Profesyonel bir karakter analisti olarak, kullanıcının verdiği cevaplardan (içe/dışa dönüklük, mantık/duygu dengesi) yola çıkarak "Kişisel Marka" ve "İletişim Stili" analizi yap. Klişe MBTI tanımlarının ötesine geç, kullanıcıya özel bir portre çiz.',
      questions: [
        TestQuestion(
          id: 'm1',
          text: 'Yabancı bir ortamdasınız ve kimseyi tanımıyorsunuz. Genelde ne yaparsınız?',
          options: [
            TestOption(text: 'Bir köşeye geçer, telefonumla ilgilenir veya gözlem yaparım', value: 0),
            TestOption(text: 'Gözüme kestirdiğim biriyle hemen havadan sudan konuşmaya başlarım', value: 10),
            TestOption(text: 'Hemen en dikkat çeken grubun içine dalarım', value: 12),
          ],
        ),
        TestQuestion(
          id: 'm2',
          text: 'Bir arkadaşınız size büyük bir hata yaptığını anlatıyor. İçinizdeki ses ne der?',
          options: [
            TestOption(text: '"Bunu neden yaptı? Mantıklı bir açıklaması olamaz." (Sorgulayıcı)', value: 10),
            TestOption(text: '"Canı ne kadar yanıyor olmalı, yanında olmalıyım." (Destekleyici)', value: 0),
            TestOption(text: '"Bu durumdan nasıl en az hasarla kurtulabilir?" (Pragmatik)', value: 10),
          ],
        ),
        TestQuestion(
          id: 'm3',
          text: 'Hayatınızın geri kalanında sadece birini seçebilirsiniz: Sürekli yeni maceralar mı, yoksa sarsılmaz bir düzen mi?',
          options: [
            TestOption(text: 'Kesinlikle düzen ve güven', value: 0),
            TestOption(text: 'Kaos ve macera beni canlı tutar', value: 10),
          ],
        ),
      ],
    ),
  ];
}
